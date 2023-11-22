{ ananasMusicControlPackage }:
{ config, pkgs, lib, ... }:
{
  systemd.services.music-control = {
    wantedBy = [ "multi-user.target" ];
    description = "Music control";
    serviceConfig = {
      Type = "simple";
      User = "root";
      ExecStart = "${ananasMusicControlPackage}/bin/ananas-music-control";
      SupplementaryGroups = "spi";
    };
  };
}