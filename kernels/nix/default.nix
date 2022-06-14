{
  self,
  pkgs,
  poetry2nix,
  nix ? pkgs.nixVersions.stable,
  # https://github.com/nix-community/poetry2nix#mkPoetryPackages
  projectDir ? null,
  pyproject ? null,
  poetrylock ? null,
  overrides ? null,
  python ? null,
  editablePackageSources ? {},
}: let
  inherit (pkgs) lib;

  addNativeBuildInputs = drv: inputs:
    drv.overridePythonAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ inputs;
    });

  env = poetry2nix.mkPoetryPackages envArgs;

  envArgs = {
    projectDir =
      if projectDir == null
      then self + "/kernels/nix"
      else projectDir;

    pyproject =
      if pyproject == null
      then envArgs.projectDir + "/pyproject.toml"
      else pyproject;

    poetrylock =
      if poetrylock == null
      then envArgs.projectDir + "/poetry.lock"
      else poetrylock;

    python =
      if python == null
      then pkgs.python3
      else python;

    overrides =
      if overrides == null
      then
        poetry2nix.overrides.withDefaults (self: super: {
          traitlets = addNativeBuildInputs super.traitlets [self.hatchling];
          terminado = addNativeBuildInputs super.terminado [self.hatchling];
          ipykernel = super.ipykernel.overridePythonAttrs (old: {
            postPatch = ''
              sed -i "/debugpy/d" setup.py
            '';
          });
        })
      else overrides;
  };

  nix-bin =
    pkgs.runCommand "wrapper-${env.python.name}"
    {nativeBuildInputs = [pkgs.makeWrapper];}
    ''
      mkdir -p $out/bin
      for i in ${env.python}/bin/*; do
        filename=$(basename $i)
        ln -s ${env.python}/bin/$filename $out/bin/$filename
        wrapProgram $out/bin/$filename \
          --set PATH ${nix}/bin
      done
    '';
in
  {
    name ? "nix",
    displayName ? "Nix", # TODO: add Nix version
    language ? "Nix",
    argv ? [
      "${nix-bin}/bin/nix-kernel"
      "-f"
      "{connection_file}"
    ],
    codemirror_mode ? "",
    logo64 ? ./logo64.png,
  }: {
    inherit
      name
      displayName
      language
      argv
      codemirror_mode
      logo64
      ;
  }
