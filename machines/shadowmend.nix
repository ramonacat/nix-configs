{ config, pkgs, lib, ... }:
{
  config = {
    fileSystems."/mnt/nas" =
      {
        device = "10.69.10.139:/mnt/data0/data";
        fsType = "nfs";
      };

    services.zoneminder = {
      enable = true;
      hostname = "localhost";
      openFirewall = true;
      database.createLocally = true;
      database.username = "zoneminder";
      cameras = 3;
    };

    services.tailscale.enable = true;
    services.logind.lidSwitch = "ignore";
    services.mysql.settings.max_threads = 64;
  };
}
