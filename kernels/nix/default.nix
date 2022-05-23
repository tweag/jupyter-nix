{
  self,
  pkgs,
  poetry2nix, # TODO: Use poetry for python environment or figure out how to modify the flake so it isn't passed by default
  nix ? pkgs.nixVersions.stable,
  pythonArg ? null,
  pythonPackagesArg ? null,
  nix-kernel-arg ? null,
}:
let
  python =
    if pythonArg == null
    then pkgs.python3
    else pythonArg;

  pythonPackages =
    if pythonPackagesArg == null
    then pkgs.python3Packages
    else pythonPackagesArg;

  nix-kernel =
    if nix-kernel-arg == null
    then (import ./nix-kernel { inherit pkgs python pythonPackages; })
    else nix-kernel-arg;

  kernelEnv = python.withPackages (ps: with ps; [ nix-kernel ]);

  nix-bin = pkgs.writeScriptBin "nix-kernel" ''
      #! ${pkgs.stdenv.shell}
      PATH=${nix}/bin/:${kernelEnv}/bin:$PATH
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
