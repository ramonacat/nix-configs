_: {
  config = {
    services = {
      jackett.enable = true;
      radarr = {
        enable = true;
        user = "nas";
      };
      sonarr = {
        enable = true;
        user = "nas";
      };
    };

    fileSystems."/var/lib/transmission/Downloads" = {
      device = "shadowsoul:/var/lib/transmission/Downloads";
      fsType = "nfs";
      options = ["x-systemd.after=tailscaled.service"];
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      9117 # jackett
      7878 # radarr
      8989 # sonarr
    ];
  };
}
