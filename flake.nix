{
  description = "Declarative and reproducible Jupyter environments - powered by Nix";

  nixConfig.extra-substituters = "https://tweag-jupyter.cachix.org";
  nixConfig.extra-trusted-public-keys = "tweag-jupyter.cachix.org-1:UtNH4Zs6hVUFpFBTLaA4ejYavPo5EFFqgd7G7FxGW9g=";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-22.05";
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

        jupyterlab = pkgs.poetry2nix.mkPoetryEnv {
          python = pkgs.python3;
          projectDir = self; # TODO: only include relevant files/folders
          overrides = pkgs.poetry2nix.overrides.withDefaults (import ./overrides.nix);
        };

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
          kernelInstance = kernel ({inherit name;} // args);

          kernelLogos = ["logo32" "logo64"];

          kernelJSON =
            lib.mapAttrs'
            (
              name: value:
                if builtins.elem name kernelLogos
                then {
                  inherit name;
                  value = baseNameOf value;
                }
                else if name == "displayName"
                then {
                  name = "display_name";
                  inherit value;
                }
                else if name == "codemirrorMode"
                then {
                  name = "codemirror_mode";
                  inherit value;
                }
                else {inherit name value;}
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
                    {inherit self pkgs;};
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

          # create directories for storing jupyter configs
          jupyterDir = pkgs.runCommand "jupyter-dir" {} ''
            mkdir -p $out/config $out/data
          '';
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
                --set JUPYTER_PATH ${kernelsString requestedKernels} \
                --set JUPYTER_CONFIG_DIR "${jupyterDir}/config" \
                --set JUPYTER_DATA_DIR "${jupyterDir}/data" \
                --set IPYTHONDIR "/path-not-set" \
                --set JUPYTER_RUNTIME_DIR "/path-not-set"
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
            example_rust = mkKernel k.rust {
              displayName = "Example Rust Kernel";
            };
            example_nix = mkKernel k.nix {
              displayName = "Example Nix Kernel";
            };
            example_bash = mkKernel k.bash {
              displayName = "Example Bash Kernel";
            };
            example_c = mkKernel k.c {
              displayName = "Example C Kernel";
            };
            example_ipython = mkKernel k.ipython {
              displayName = "Example IPython Kernel";
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
