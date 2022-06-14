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
      then self + "/kernels/bash"
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
        })
      else overrides;
  };
in
  {
    name ? "bash",
    displayName ? "Bash", # TODO: add Bash version
    language ? "bash",
    argv ? [
      "${env.python.interpreter}"
      "-m"
      "bash_kernel"
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
