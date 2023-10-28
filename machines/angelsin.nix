{ config, pkgs, lib, ... }:
{
  config = {
    services.tlp.enable = true;
    services.upower.enable = true;

    services.syncthing = {
      enable = true;
      overrideDevices = true;
      overrideFolders = true;
      user = "ramona";

      dataDir = "/home/ramona/.syncthing-data";
      configDir = "/home/ramona/.config/syncthing";

      settings = {
        devices = {
          "phone" = { "id" = "VZK66I4-WTFCOWJ-B7LH6QV-FDQFTSH-FTBWTIH-UUDRUOR-SNIZBPS-AMRDBAU"; };
          "hallewell" = { "id" = "BKZEEQS-2VYH2DZ-FRANPJH-I4WOFMZ-DO3N7AJ-XSK7J3D-P57XCTW-S66ZEQY"; };
          "tablet" = { "id" = "RRUE6ZX-AXPN4HG-DUFIBV5-A4A3CTI-KQ3QO25-7WTBNWM-OUMDZUA-NLFBVQK"; };
          "moonfall" = { "id" = "PXWTJI7-L6TU2HC-DTB6OCO-B2UWS26-6I562FU-VMXOQSZ-76G6POM-JJBJRQR"; };
        };

        folders = {
          "shared" = {
            path = "/home/ramona/shared/";
            devices = [ "phone" "hallewell" "tablet" "moonfall" ];
          };
        };
      };
    };

    # For syncthing
    networking.firewall.allowedTCPPorts = [ 22000 ];
    networking.firewall.allowedUDPPorts = [ 22000 21027 ];
  };
}