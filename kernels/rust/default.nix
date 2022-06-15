{
  self,
  pkgs,
  evcxr ? pkgs.evcxr,
  # https://github.com/nix-community/poetry2nix#mkPoetryEnv
  projectDir ? self + "/kernels/rust",
  pyproject ? projectDir + "/pyproject.toml",
  poetrylock ? projectDir + "/poetry.lock",
  overrides ? pkgs.poetry2nix.overrides.withDefaults (import ./overrides.nix),
  python ? pkgs.python3,
  editablePackageSources ? {},
  extraPackages ? ps: [],
  preferWheels ? false,
}: let
  /*
   env = pkgs.poetry2nix.mkPoetryEnv {
     inherit
       projectDir
       pyproject
       poetrylock
       overrides
       python
       editablePackageSources
       extraPackages
       preferWheels
       ;
   };
   */
in
  {
    name ? "rust",
    displayName ? "Rust", # TODO: add Rust version
    language ? "rust",
    argv ? [
      "${evcxr}/bin/evcxr_jupyter"
      "--control_file"
      "{connection_file}"
    ],
    codemirror_mode ? "rust",
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
