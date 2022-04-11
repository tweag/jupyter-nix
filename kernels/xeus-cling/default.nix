{
  writeScriptBin,
  stdenv,
  lib,
  fetchurl,
  python,
  wget,
  fetchFromGitHub,
  libffi,
  cacert,
  git,
  cmake,
  llvm,
  cppzmq,
  openssl,
  glibc,
  makeWrapper,
  cryptopp,
  ncurses,
  llvmPackages,
  zlib,
  zeromq,
  pkgconfig,
  libuuid,
  pugixml,
  fetchgit,
  name ? "nixpkgs",
  packages ? (_: []),
}: let
  cling = import ./cling.nix {inherit stdenv fetchurl python wget fetchFromGitHub libffi cacert git cmake llvm ncurses zlib fetchgit glibc makeWrapper;};
  xeusCling = import ./xeusCling.nix {
    inherit stdenv fetchFromGitHub cmake zeromq pkgconfig libuuid cling llvmPackages pugixml llvm cppzmq openssl glibc makeWrapper cryptopp;
  };

  xeusClingSh = writeScriptBin "xeusCling" ''
    #! ${stdenv.shell}
    export PATH="${lib.makeBinPath [xeusCling]}:$PATH"
    ${xeusCling}/bin/xeus-cling "$@"'';

  kernelFile = {
    display_name =
      "C++"
      + (
        if name == ""
        then ""
        else " - ${name}"
      );
    language = "C++11";
    argv = [
      "${xeusClingSh}/bin/xeusCling"
      "-f"
      "{connection_file}"
      "-std=c++11"
    ];
    logo64 = "logo-64x64.svg";
  };

  xeusClingKernel = stdenv.mkDerivation {
    name = "xeus-cling";
    phases = "installPhase";
    src = ./xeus-cling.svg;
    buildInputs = [xeusCling];
    installPhase = ''
      mkdir -p $out/kernels/xeusCling_${name}
      cp $src $out/kernels/xeusCling_${name}/logo-64x64.svg
      echo '${builtins.toJSON kernelFile}' > $out/kernels/xeusCling_${name}/kernel.json
    '';
  };
in {
  spec = xeusClingKernel;
  runtimePackages = [];
}
