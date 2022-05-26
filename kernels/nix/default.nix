{
  self,
  pkgs,
  poetry2nix,
  nix ? pkgs.nixVersions.stable,
  projectDir ? null,
  pyproject ? null,
  poetrylock ? null,
  python ? null,
}:
let
  env = poetry2nix.mkPoetryPackages
  {
    projectDir =
      if projectDir == null
      then self + "/kernels/nix"
      else projectDir;

    pyproject =
      if pyproject == null
      then projectDir + "/pyproject.toml"
      else pyproject;

    poetrylock =
      if poetrylock == null
      then projectDir + "/poetry.lock"
      else poetrylock;

    python =
      if python == null
      then pkgs.python3
      else python;
  };

  nix-bin = pkgs.writeScriptBin "nix-kernel"
    ''
      #! ${pkgs.stdenv.shell}
      PATH=${nix}/bin/:${env.python}/bin:$PATH
      exec python -m nix-kernel $@
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
  }:
    {
      inherit
        name
        displayName
        language
        argv
        codemirror_mode
        logo64
        ;
    }
