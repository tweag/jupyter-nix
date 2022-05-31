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

  _projectDir =
    if projectDir == null
    then self + "/kernels/nix"
    else projectDir;

  env =
    poetry2nix.mkPoetryApplication
    {
      projectDir = _projectDir;

      pyproject =
        if pyproject == null
        then _projectDir + "/pyproject.toml"
        else pyproject;

      poetrylock =
        if poetrylock == null
        then _projectDir + "/poetry.lock"
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

  # Transform python3.9-xxxx-1.8.0 to xxxx
  toName = s:
    lib.strings.concatStringsSep "-"
    (lib.lists.drop 1 (lib.lists.init (lib.strings.splitString "-" s)));

  # Makes the flat list an attrset
  packages = builtins.foldl' (obj: drv: {"${toName drv.name}" = drv;} // obj) {} env.poetryPackages;

  nix-bin =
    pkgs.runCommand "wrapper-${env.name}"
    {nativeBuildInputs = [pkgs.makeWrapper];}
    ''
      mkdir -p $out/bin
      for i in ${env}/bin/*; do
        filename=$(basename $i)
        ln -s ${env}/bin/$filename $out/bin/$filename
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
