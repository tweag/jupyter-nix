{
  description = "Declarative and reproducible Jupyter environments - powered by Nix";

  nixConfig.extra-substituters = "https://tweag-jupyter.cachix.org";
  nixConfig.extra-trusted-public-keys = "tweag-jupyter.cachix.org-1:UtNH4Zs6hVUFpFBTLaA4ejYavPo5EFFqgd7G7FxGW9g=";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-21.11";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.gitignore.url = "github:hercules-ci/gitignore.nix";
  inputs.gitignore.inputs.nixpkgs.follows = "nixpkgs";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  inputs.pre-commit-hooks.inputs.flake-utils.follows = "flake-utils";
  inputs.pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";
  inputs.poetry2nix.inputs.flake-utils.follows = "flake-utils";
  inputs.poetry2nix.inputs.nixpkgs.follows = "nixpkgs";
  #inputs.ihaskell.url = "github:gibiansky/IHaskell";
  #inputs.ihaskell.inputs.nixpkgs.follows = "nixpkgs";
  #inputs.ihaskell.inputs.flake-compat.follows = "flake-compat";
  #inputs.ihaskell.inputs.flake-utils.follows = "flake-utils";

  # TODO: For some reason I can not override anything in hls
  #inputs.ihaskell.inputs.hls.inputs.flake-compat.follows = "flake-compat";
  #inputs.ihaskell.inputs.hls.inputs.flake-utils.follows = "flake-utils";
  #inputs.ihaskell.inputs.hls.inputs.nixpkgs.follows = "nixpkgs";
  #inputs.ihaskell.inputs.hls.inputs.pre-commit-hooks.follows = "pre-commit-hooks";

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    flake-compat,
    flake-utils,
    gitignore,
    pre-commit-hooks,
    poetry2nix,
    #ihaskell,
  } @ inputs: let
    SYSTEMS = [
      flake-utils.lib.system.x86_64-linux
      flake-utils.lib.system.x86_64-darwin
    ];
  in
    (flake-utils.lib.eachSystem SYSTEMS (
      system: let
        inherit (nixpkgs) lib;

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            poetry2nix.overlay
          ];
        };

        pkgs_stable = import nixpkgs-stable {
          inherit system;
          overlays = [
            poetry2nix.overlay
          ];
        };

        pre-commit = pre-commit-hooks.lib.${system}.run {
          src = gitignore.lib.gitignoreSource self;
          hooks = {
            alejandra.enable = true;
          };
        };

        jupyterlab = let
          addNativeBuildInputs = drv: inputs:
            drv.overridePythonAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or []) ++ inputs;
            });

          poetryPackages = pkgs.poetry2nix.mkPoetryPackages {
            python = pkgs.python3;
            projectDir = ./.;
            overrides = pkgs.poetry2nix.overrides.withDefaults (self: super: {
              argon2-cffi = addNativeBuildInputs super.argon2-cffi [self.flit-core];
              entrypoints = addNativeBuildInputs super.entrypoints [self.flit-core];
              jupyterlab-pygments = addNativeBuildInputs super.jupyterlab-pygments [self.jupyter-packaging];
              notebook-shim = addNativeBuildInputs super.notebook-shim [self.jupyter-packaging];
              pyparsing = addNativeBuildInputs super.pyparsing [self.flit-core];
              soupsieve = addNativeBuildInputs super.soupsieve [self.hatchling];
              testpath = addNativeBuildInputs super.testpath [self.flit-core];
            });
          };

          # Transform python3.9-xxxx-1.8.0 to xxxx
          toName = s:
            lib.strings.concatStringsSep "-"
            (lib.lists.drop 1 (lib.lists.init (lib.strings.splitString "-" s)));

          # Makes the flat list an attrset
          packages = builtins.foldl' (obj: drv: {"${toName drv.name}" = drv;} // obj) {} poetryPackages.poetryPackages;
        in
          packages.jupyterlab;

        mkKernel = kernel: args: name: let
          # TODO: we should probably assert that the kernel is correctly shaped.
          #{ name,                    # required; type: string
          #, language,                # required; type: enum or string
          #, argv,                    # required; type: list of strings
          #, display_name ? name      # optional; type: string
          #, codemirror_mode ? "yaml" # optional; type: enum or string
          #, logo32,                  # optional; type: absolute store path
          #, logo64,                  # optional; type: absolute store path
          #}:
          args' =
            lib.mapAttrs'
            (
              name: value:
                if name == "displayName"
                then {
                  name = "display_name";
                  inherit value;
                }
                else {inherit name value;}
            )
            args;

          kernelInstance = kernel ({inherit name;} // args);

          kernelLogos = ["logo32" "logo64"];

          kernelJSON =
            builtins.mapAttrs
            (
              n: v:
                if builtins.elem n kernelLogos
                then baseNameOf v
                else v
            )
            kernelInstance;

          copyKernelLogos =
            builtins.concatStringsSep "\n"
            (
              builtins.map
              (
                logo: let
                  kernelLogoPath = kernelInstance.${logo};
                in
                  lib.optionalString (builtins.hasAttr logo kernelInstance) ''
                    cp ${kernelLogoPath} $out/kernels/${kernelInstance.name}/${baseNameOf kernelLogoPath}
                  ''
              )
              kernelLogos
            );
        in
          pkgs.runCommand "${kernelInstance.name}-jupyter-kernel"
          {
            passthru = {
              inherit kernel kernelInstance kernelJSON;
              IS_JUPYTER_KERNEL = true;
            };
          }
          (
            ''
              mkdir -p $out/kernels/${kernelInstance.name}
              echo '${builtins.toJSON kernelJSON}' \
                > $out/kernels/${name}/kernel.json
            ''
            + copyKernelLogos
          );

        mkJupyterlabInstance = {
          kernels ? k: {}, # k: { python: k.python {}; },
          extensions ? e: [], # e: [ e.jupy-ext ],
        }: let
          kernelsPath = self + "/kernels";

          availableKernels =
            lib.optionalAttrs
            (lib.pathExists kernelsPath)
            (
              lib.mapAttrs'
              (
                kernelName: _: {
                  name = kernelName;
                  value =
                    lib.makeOverridable
                    (import (kernelsPath + "/${kernelName}/default.nix"))
                    {
                      inherit self pkgs;
                      inherit (pkgs) poetry2nix;
                    };
                }
              )
              (
                lib.filterAttrs
                (
                  kernelName: pathType:
                    pathType
                    == "directory"
                    && lib.pathExists (kernelsPath + "/${kernelName}/default.nix")
                )
                (builtins.readDir kernelsPath)
              )
            );

          kernelInstances =
            lib.mapAttrsToList
            # TODO: provide a nice error message when something is not a function with one argument
            (kernelName: kernel: kernel kernelName)
            (kernels availableKernels);

          requestedKernels =
            builtins.filter
            (
              kernel:
              # TODO: provide a nice error message when something is not a kernel
                lib.isDerivation kernel
                && builtins.hasAttr "IS_JUPYTER_KERNEL" kernel
                && kernel.IS_JUPYTER_KERNEL == true
            )
            kernelInstances;

          kernelsString = lib.concatStringsSep ":";
        in
          pkgs.runCommand "wrapper-${jupyterlab.name}"
          {nativeBuildInputs = [pkgs.makeWrapper];}
          ''
            mkdir -p $out/bin
            for i in ${jupyterlab}/bin/*; do
              filename=$(basename $i)
              ln -s ${jupyterlab}/bin/$filename $out/bin/$filename
              wrapProgram $out/bin/$filename \
                --set JUPYTERLAB_DIR ${jupyterlab}/share/jupyter/lab \
                --set JUPYTER_PATH ${kernelsString requestedKernels}
            done
          '';

        example_jupyterlab = mkJupyterlabInstance {
          kernels = k: let
            ansible_stable = k.ansible.override {
              pkgs = pkgs_stable;
            };
          in {
            example_ansible_stable = mkKernel ansible_stable {
              displayName = "Example (stable) Ansible Kernel";
            };
            example_ansible = mkKernel k.ansible {
              displayName = "Example Ansible Kernel";
            };
            example_nix = mkKernel k.nix {
              displayName = "Example Nix Kernel";
            };
          };
        };
      in rec {
        lib = {inherit mkKernel mkJupyterlabInstance;};
        packages = {inherit jupyterlab example_jupyterlab;};
        packages.default = packages.jupyterlab;
        devShell = pkgs.mkShell {
          packages = [
            pkgs.alejandra
            poetry2nix.defaultPackage.${system}
            pkgs.python3Packages.poetry

            # ansible kernel
            pkgs.stdenv.cc.cc.lib
          ];
          shellHook = ''
            ${pre-commit.shellHook}
          '';
        };
        checks = {
          inherit pre-commit jupyterlab example_jupyterlab;
        };
      }
    ))
    // {
      defaultTemplate = {
        path = ./template;
        description = "Boilerplate for your jupyter-nix project";
      };
    };
}
