{
  description = "Root flake for my machines";

  inputs = {
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";

    };

    agenix.url = "github:ryantm/agenix";
    alacritty-theme.url = "github:alexghr/alacritty-theme.nix";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs.url = "nixpkgs/nixos-unstable-small";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, home-manager, rust-overlay, crane, nixos-hardware, agenix, nix-vscode-extensions, nix-minecraft, alacritty-theme }:
    let
      overlays = [
        (import rust-overlay)
        nix-minecraft.overlay
        alacritty-theme.overlays.default
        (final: prev: {
          ramona.lan-mouse = (import ./packages/lan-mouse.nix) { inherit pkgs craneLib; };
        })
      ];
      pkgsConfig = {
        allowUnfree = true;
        android_sdk.accept_license = true;
      };
      pkgs = import nixpkgs {
        inherit overlays;
        system = "x86_64-linux";
        config = pkgsConfig // {
          # Dark magic for transcoding acceleration on hallewell
          packageOverrides = pkgs: {
            vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
          };
          permittedInsecurePackages = [
            "electron-25.9.0"
          ];
        };
      };
      pkgsAarch64 = import nixpkgs { inherit overlays; system = "aarch64-linux"; config = pkgsConfig; };
      pkgsCross = import nixpkgs { inherit overlays; localSystem = "x86_64-linux"; crossSystem = "aarch64-linux"; config = pkgsConfig; };
      craneLib = (crane.mkLib pkgs).overrideToolchain rustVersion;
      rustVersion = pkgs.rust-bin.stable.latest.default;
      rustVersionAarch64 = pkgsAarch64.rust-bin.stable.latest.default;
      craneLibAarch64 = (crane.mkLib pkgsAarch64).overrideToolchain rustVersionAarch64;

      homeAutomationPackage = import ./packages/home-automation.nix { inherit pkgs; inherit craneLib; };
      ananasMusicControlPackage = import ./packages/music-control.nix { pkgs = pkgsAarch64; craneLib = craneLibAarch64; };
      ratPackage = import ./packages/rat.nix { inherit pkgs; inherit craneLib; };
      shellScripts = builtins.concatStringsSep " " (builtins.filter (x: pkgs.lib.hasSuffix ".sh" x) (pkgs.lib.filesystem.listFilesRecursive ./.));
    in
    {
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
      checks.x86_64-linux = {
        fmt-nix = pkgs.runCommand "fmt-nix" { } ''
          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}

          touch $out
        '';
        fmt-lua = pkgs.runCommand "fmt-lua" { } ''
          ${pkgs.stylua}/bin/stylua --check ${./.}

          touch $out
        '';
        shellcheck = pkgs.runCommand "shellcheck" { } ''
          ${pkgs.shellcheck}/bin/shellcheck ${shellScripts}

          touch $out
        '';
      };
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          pkg-config
          pipewire
          clang
          alsaLib.dev
          rust-analyzer
          lua-language-server
          terraform
          google-cloud-sdk
          stylua
          terraform-ls
          (pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" ];
            targets = [ "aarch64-unknown-linux-gnu" ];
          })
        ];
        LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
      };
      nixosConfigurations = {
        hallewell = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })

            ./machines/hallewell/grafana.nix
            ./machines/hallewell/hardware.nix
            ./machines/hallewell/minio.nix
            ./machines/hallewell/nas.nix
            ./machines/hallewell/networking.nix
            ./machines/hallewell/paperless.nix
            ./machines/hallewell/postgresql.nix
            ./machines/hallewell/tempo.nix
            ./machines/hallewell/users/ramona.nix
            ./modules/bcachefs.nix
            ./modules/updates.nix
            ./modules/installed_base.nix
            ./modules/syncthing.nix
            ./modules/telegraf.nix
          ];
        };
        moonfall = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })
            (import ./users/ramona/gui.nix { inherit nix-vscode-extensions; })

            ./machines/moonfall/hardware.nix
            ./machines/moonfall/networking.nix
            ./machines/moonfall/users/ramona_gui.nix
            ./machines/moonfall/virtualisation.nix
            ./modules/greetd.nix
            ./modules/installed_base.nix
            ./modules/nas-client.nix
            ./modules/steam.nix
            ./modules/syncthing.nix
            ./modules/telegraf.nix
            ./modules/terraform-tokens.nix
            ./modules/updates.nix
            ./modules/workstation.nix
            ./users/ramona/sway.nix
          ];
        };
        shadowmend = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })
            (import ./machines/shadowmend/home-automation.nix { inherit homeAutomationPackage; })

            ./machines/shadowmend/hardware.nix
            ./machines/shadowmend/networking.nix
            ./machines/shadowmend/rabbitmq.nix
            ./machines/shadowmend/users/ramona.nix
            ./machines/shadowmend/zigbee2mqtt.nix
            ./modules/bcachefs.nix
            ./modules/updates.nix
            ./modules/installed_base.nix
            ./modules/nas-client.nix
            ./modules/telegraf.nix
          ];
        };
        angelsin = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            nixos-hardware.nixosModules.framework-13-7040-amd

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })
            (import ./users/ramona/gui.nix { inherit nix-vscode-extensions; })

            ./machines/angelsin/hardware.nix
            ./machines/angelsin/networking.nix
            ./machines/angelsin/users/ramona_gui.nix
            ./machines/angelsin/virtual-screen.nix
            ./modules/greetd.nix
            ./modules/installed_base.nix
            ./modules/nas-client.nix
            ./modules/steam.nix
            ./modules/syncthing.nix
            ./modules/telegraf.nix
            ./modules/terraform-tokens.nix
            ./modules/updates.nix
            ./modules/workstation.nix
            ./users/ramona/sway.nix
          ];
        };
        ananas = nixpkgs.lib.nixosSystem {
          pkgs = pkgsAarch64;
          system = "aarch64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            nixos-hardware.nixosModules.raspberry-pi-4

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })
            (import ./machines/ananas/hardware.nix { inherit pkgsCross; })
            (import ./machines/ananas/music-control.nix { inherit ananasMusicControlPackage; })

            ./machines/ananas/networking.nix
            ./modules/installed_base.nix
            ./modules/updates.nix
            ./modules/nas-client.nix
            ./modules/telegraf.nix
          ];
        };
        evillian = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            nixos-hardware.nixosModules.microsoft-surface-go

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })
            (import ./users/ramona/gui.nix { inherit nix-vscode-extensions; })

            ./machines/evillian/hardware.nix
            ./machines/evillian/networking.nix
            ./modules/greetd.nix
            ./modules/installed_base.nix
            ./modules/nas-client.nix
            ./modules/syncthing.nix
            ./modules/telegraf.nix
            ./modules/updates.nix
            ./modules/workstation.nix
            ./users/ramona/sway.nix
          ];
        };
        caligari = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default
            nix-minecraft.nixosModules.minecraft-servers

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })

            ./machines/caligari/github-runner.nix
            ./machines/caligari/hardware.nix
            ./machines/caligari/minecraft.nix
            ./machines/caligari/networking.nix
            ./machines/caligari/nginx.nix
            ./modules/bcachefs.nix
            ./modules/updates.nix
            ./modules/installed_base.nix
            ./modules/minecraft.nix
            ./modules/telegraf.nix
          ];
        };
        iso = nixpkgs.lib.nixosSystem {
          inherit pkgs;
          system = "x86_64-linux";
          modules = [
            home-manager.nixosModules.home-manager
            agenix.nixosModules.default

            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

            (import ./modules/base.nix { inherit nixpkgs; })
            (import ./users/ramona.nix { inherit agenix ratPackage; })

            ./modules/bcachefs.nix
            ./modules/iso.nix
          ];
        };
      };
    };
}
