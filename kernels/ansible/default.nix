let
  addNativeBuildInputs = drv: inputs:
    drv.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ inputs;
    });
in
  {
    self,
    pkgs,
    # https://github.com/nix-community/poetry2nix#mkPoetryPackages
    projectDir ? self + "/kernels/ansible",
    pyproject ? projectDir + "/pyproject.toml",
    poetrylock ? projectDir + "/poetry.lock",
    overrides ?
      pkgs.poetry2nix.overrides.withDefaults (self: super: {
        ansible-runner = addNativeBuildInputs super.ansible-runner [self.pbr];
        argon2-cffi = addNativeBuildInputs super.argon2-cffi [self.flit-core];
        jupyterlab-pygments = addNativeBuildInputs super.jupyterlab-pygments [self.jupyter-packaging];
        pyparsing = addNativeBuildInputs super.pyparsing [self.flit-core];
        soupsieve = addNativeBuildInputs super.soupsieve [self.hatchling];
        ansible-kernel = super.ansible-kernel.overridePythonAttrs (old: {
          postPatch = ''
            # remove when merged
            # https://github.com/ansible/ansible-jupyter-kernel/pull/82
            touch LICENSE.md

            # remove custom install
            sed -i "s/cmdclass={'install': Installer},//" setup.py
          '';
        });
      }),
    python ? pkgs.python3,
    editablePackageSources ? {},
  }: let
    pythonEnv = pkgs.poetry2nix.mkPoetryPackages {
      inherit
        projectDir
        pyproject
        poetrylock
        overrides
        python
        editablePackageSources
        ;
    };
  in
    pythonEnv
#
#{ display_name ? "Ansible ${pythonEnv."
#}:
#{
#  name = "ansible";
#  # TODO: add Ansible version
#  display_name = "Ansible";
#  language = "ansible";
#  argv = [
#    "${pythonEnv.interpreter}"
#    "-m"
#    "ansible_kernel"
#    "-f"
#    "{connection_file}"
#  ];
#  # TODO: codemirror_mode = "yaml";
#  # TODO: handle suffixes
#  #logo64 = ./logo64.svg;
#}

