{
  description = "declarative and reproducible Jupyter environments - powered by Nix";

  nixConfig.extra-substituters = "https://jupyterwith.cachix.org";
  nixConfig.extra-trusted-public-keys = "jupyterwith.cachix.org-1:/kDy2B6YEhXGJuNguG1qyqIodMyO4w8KwWH4/vAc7CI=";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-compat.url = "github:edolstra/flake-compat";
  inputs.flake-compat.flake = false;
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.gitignore.url = "github:hercules-ci/gitignore.nix";
  inputs.gitignore.inputs.nixpkgs.follows = "nixpkgs";
  inputs.pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  inputs.pre-commit-hooks.inputs.flake-utils.follows = "flake-utils";
  inputs.pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";
  #inputs.poetry2nix.inputs.flake-utils.follows = "flake-utils";
  #inputs.poetry2nix.inputs.nixpkgs.follows = "nixpkgs";
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
        pkgs = import nixpkgs {
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

        jupyterlab = import ./nix/jupyter {
          inherit (pkgs) lib poetry2nix;
          python = pkgs.python3;
        };

        copyKernelLogo = name: logo: filename:
          pkgs.lib.optionalString (logo != null) ''
            cp ${logo} $out/kernels/${name}/${filename}
          '';

        mkKernel = {
          name,
          display_name,
          language,
          argv,
          logo32 ? null,
          logo64 ? null,
        }:
        # TODO: add logos to kernel.json
          pkgs.runCommand "${name}-jupyter-kernel" {} (
            ''
              mkdir -p $out/kernels/${name}
              echo '${builtins.toJSON {inherit display_name language argv;}}' \
                > $out/kernels/${name}/kernel.json
            ''
            + (copyKernelLogo name logo32 "logo-32x32.png")
            + (copyKernelLogo name logo64 "logo-64x64.png")
          );

        # kernel
        mkKernelAnsible = {display_name ? null}:
        # https://github.com/nix-community/poetry2nix#mkPoetryEnv
        {
          self,
          pkgs,
          projectDir,
          pyproject,
          poetrylock,
          python,
          overrides,
          editablePackageSources,
          extraPackages,
        }:
          mkKernel (import ./kernels/ansible/default.nix {inherit self pkgs;});

        kernelsString = pkgs.lib.concatStringsSep ":";

        mkJupyterlabInstance = {
          kernels,
          # TODO:, extensions
        }:
          pkgs.runCommand "wrapper-${jupyterlab.name}"
          {nativeBuildInputs = [pkgs.makeWrapper];}
          ''
            mkdir -p $out/bin
            for i in ${jupyterlab}/bin/*; do
              filename=$(basename $i)
              ln -s ${jupyterlab}/bin/$filename $out/bin/$filename
              wrapProgram $out/bin/$filename --set JUPYTER_PATH ${kernelsString kernels}
            done
          '';
        # In project:
        #mkAnsible = jupyter-nix.lib.mkKernelAnsible.override { projectDir = ./different-ansible-kernel; };
        #myjupyter = mkJupyterlabInstance {
        #  kernels = [
        #    (jupyter-nix.lib.mkKernelAnsible {})
        #  ];
        #};
        # as TOML v1
        # [myjupyter]
        # kernels = [ "ansible" ]
        # extensions = [ "ssss" ]
        #
        # as TOML v1.5
        # [myjupyter]
        # extensions = [ "ssss" ]
        #
        # [myjupyter.kernels.mypython3]
        # type = "python3"
        # projectDir = "./mypython3"
        # overrides = "./mypython3/overrides.nix"
        #
        # as TOML v2
        # [myjupyter]
        # extensions = [ "ssss" ]
        #
        # [myjupyter.kernels.mypython3]
        # type = "python3"
        # extra-dependencies = [
        #   "requests"
        # ]
        # overrides = "./mypython3/overrides.nix"
      in rec {
        packages = {inherit jupyterlab;};
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
          inherit pre-commit jupyterlab;
          #test-ansible = mkJupyterlabInstance { kernels = [ kernel-ansible ]; };
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
