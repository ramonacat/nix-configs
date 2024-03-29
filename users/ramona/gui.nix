{nix-vscode-extensions}: {
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  # colors: https://coolors.co/ff1885-19323c-9da2ab-f3de8a-988f2a
  config = {
    # LANMouse
    networking.firewall.allowedUDPPorts = [4242];

    # pipewire over network
    networking.firewall.allowedTCPPorts = [4656];

    home-manager.users.ramona =
      {
        programs.firefox.enable = true;
        programs.alacritty = {
          enable = true;
          settings = {
            font = {
              size = 16;
            };
            window.opacity = 0.8;
            import = [
              pkgs.alacritty-theme.kanagawa_dragon
            ];
          };
        };
        services.gpg-agent.pinentryPackage = pkgs.pinentry-qt;

        home.packages = with pkgs; [
          dconf
          discord
          flac
          grip
          hunspell
          hunspellDicts.de_DE
          hunspellDicts.en_US
          hunspellDicts.pl_PL
          ramona.lan-mouse
          keepassxc
          krita
          light
          loupe
          moc
          obs-studio
          obsidian
          pamixer
          pavucontrol
          playerctl
          spotify
          virt-manager
          vlc
          xdg-utils

          factorio
          prismlauncher
        ];

        home.pointerCursor = {
          name = "Adwaita";
          package = pkgs.gnome.adwaita-icon-theme;
          size = 36;
          x11 = {
            enable = true;
            defaultCursor = "Adwaita";
          };
        };

        programs.vscode = {
          enable = true;
          mutableExtensionsDir = false;
          extensions = with nix-vscode-extensions.extensions.x86_64-linux.vscode-marketplace; [
            panicbit.cargo
            devsense.composer-php-vscode
            ms-azuretools.vscode-docker
            tamasfe.even-better-toml
            github.vscode-github-actions
            ms-kubernetes-tools.vscode-kubernetes-tools
            bbenoist.nix
            jnoortheen.nix-ide
            ms-ossdata.vscode-postgresql
            arrterian.nix-env-selector
            rust-lang.rust-analyzer
            bbenoist.nix
            arrterian.nix-env-selector
            thenuprojectcontributors.vscode-nushell-lang
            hashicorp.terraform
          ];
          userSettings = {
            "workbench.colorTheme" = "Visual Studio Dark";
            "window.zoomLevel" = 1;
            "editor.fontFamily" = "'Iosevka', 'monospace', monospace";
            "files.autoSave" = "onFocusChange";
            "editor.cursorBlinking" = "smooth";
            "editor.fontLigatures" = true;
            "editor.mouseWheelZoom" = true;
          };
        };

        gtk = {
          enable = true;
          theme = {
            package = pkgs.dracula-theme;
            name = "Dracula";
          };
        };

        qt = {
          enable = true;
          style.name = "Dracula";
          platformTheme = "gtk3";
        };

        home.file.".moc/config".text = ''
          Theme = nightly_theme
        '';
      }
      // (
        if (config.networking.hostName == "moonfall" || config.networking.hostName == "angelsin")
        then {
          systemd.user.services.lan-mouse = {
            Unit = {
              Description = "LAN Mouse";
            };
            Install = {
              WantedBy = ["graphical-session.target"];
            };
            Service = {
              ExecStart = pkgs.writeScript "lan-mouse-and-stuff" (
                ''
                  #!${pkgs.stdenv.shell}

                ''
                + (
                  if config.networking.hostName == "moonfall"
                  then ''
                    ${pkgs.pulseaudio}/bin/pactl load-module module-native-protocol-tcp port=4656
                  ''
                  else ''
                    ${pkgs.pulseaudio}/bin/pactl load-module module-tunnel-sink server=tcp:10.69.10.29:4656
                  ''
                )
                + "${pkgs.ramona.lan-mouse}/bin/lan-mouse --daemon"
              );
              Restart = "always";
            };
          };
          xdg.configFile."lan-mouse/config.toml".text =
            if config.networking.hostName == "moonfall"
            then ''
              [top]
              hostname = "10.69.10.33"
              activate_on_startup = true
            ''
            else ''
              [bottom]
              hostname = "10.69.10.29"
              activate_on_startup = true
            '';
        }
        else {}
      );
  };
}
