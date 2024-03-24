{
  pkgs,
  poetry2nix,
}: let
  src = ../apps/hat;
  packageArguments = {projectDir = src;};
in rec {
  package = poetry2nix.mkPoetryApplication packageArguments;
  coverage = pkgs.runCommand "empty-coverage" {} "true";
  checks = let
    environment = poetry2nix.mkPoetryEnv packageArguments;
  in {
    "${package.name}--fmt" = pkgs.runCommand "${package.name}--fmt" {} "PATH=${environment}/bin/:$PATH black --check ${src}; touch $out";
    "${package.name}--types" = pkgs.runCommand "${package.name}--types" {} ''
      pushd ${src}
      PATH=${pkgs.pyright}/bin/:${environment}/bin/:$PATH pyright
      touch $out
    '';
  };
}
