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

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.3.0";

      inputs.nixpkgs.follows = "nixpkgs";
    };

    lix = {
      url = "git+ssh://git@lix.systems/lix-project/lix";
      flake = false;
    };

    lix-module = {
      url = "git+ssh://git@lix.systems/lix-project/nixos-module";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };

    agenix.url = "github:ryantm/agenix";
    alacritty-theme.url = "github:alexghr/alacritty-theme.nix";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nixpkgs.url = "nixpkgs/nixos-unstable-small";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = {
    nixpkgs,
    home-manager,
    rust-overlay,
    crane,
    nixos-hardware,
    agenix,
    nix-minecraft,
    alacritty-theme,
    lanzaboote,
    lix-module,
    ...
  }: let
    packages = {
      home-automation = import ./packages/home-automation.nix;
      music-control = import ./packages/music-control.nix;
      rad = import ./packages/rad.nix;
      ras = import ./packages/ras.nix;
      rat = import ./packages/rat.nix;
      ratweb = import ./packages/ratweb.nix;
      hat = import ./packages/hat.nix;
    };
    libraries = {
      ratlib = import ./packages/libraries/ratlib.nix;
    };
    overlays = let
      common = [
        (import rust-overlay)
      ];
      mine = architecture: {
        pkgs,
        craneLib,
      }: (_: prev: {
        agenix = agenix.packages."${architecture}-linux".default;
        ramona =
          {
            lan-mouse = (import ./packages/lan-mouse.nix) {inherit pkgs craneLib;};
          }
          // prev.lib.mapAttrs' (name: value: {
            name = "${name}";
            value = (value {inherit pkgs craneLib;}).package;
          })
          packages;
      });
    in {
      x86_64 =
        common
        ++ [
          nix-minecraft.overlay
          alacritty-theme.overlays.default
          (mine "x86_64" {inherit pkgs craneLib;})
        ];
      aarch64 =
        common
        ++ [
          (mine "aarch64" {
            pkgs = pkgsAarch64;
            craneLib = craneLibAarch64;
          })
        ];
    };
    pkgsConfig = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
    pkgs = import nixpkgs {
      overlays = overlays.x86_64;
      system = "x86_64-linux";
      config =
        pkgsConfig
        // {
          # Dark magic for transcoding acceleration on hallewell
          packageOverrides = pkgs: {
            vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
          };
        };
    };
    pkgsAarch64 = import nixpkgs {
      overlays = overlays.aarch64;
      system = "aarch64-linux";
      config = pkgsConfig;
    };
    pkgsCross = import nixpkgs {
      overlays = overlays.aarch64;
      localSystem = "x86_64-linux";
      crossSystem = "aarch64-linux";
      config = pkgsConfig;
    };
    craneLib = (crane.mkLib pkgs).overrideToolchain rustVersion;
    rustVersion = pkgs.rust-bin.stable.latest.default.override {
      extensions = ["llvm-tools-preview"];
      targets = ["wasm32-unknown-unknown"];
    };
    rustVersionAarch64 = pkgsAarch64.rust-bin.stable.latest.default.override {extensions = ["llvm-tools-preview"];};
    craneLibAarch64 = (crane.mkLib pkgsAarch64).overrideToolchain rustVersionAarch64;

    shellScripts = builtins.concatStringsSep " " (builtins.filter (x: pkgs.lib.hasSuffix ".sh" x) (pkgs.lib.filesystem.listFilesRecursive (pkgs.lib.cleanSource ./.)));
  in {
    formatter.x86_64-linux = pkgs.alejandra;
    checks.x86_64-linux =
      {
        fmt-nix = pkgs.runCommand "fmt-nix" {} ''
          ${pkgs.alejandra}/bin/alejandra --check ${./.}

          touch $out
        '';
        fmt-lua = pkgs.runCommand "fmt-lua" {} ''
          ${pkgs.stylua}/bin/stylua --check ${./.}

          touch $out
        '';
        deadnix = pkgs.runCommand "deadnix" {} ''
          ${pkgs.deadnix}/bin/deadnix --fail ${./.}

          touch $out
        '';
        statix = pkgs.runCommand "statix" {} ''
          ${pkgs.statix}/bin/statix check ${./.}

          touch $out
        '';
        shellcheck = pkgs.runCommand "shellcheck" {} ''
          ${pkgs.shellcheck}/bin/shellcheck ${shellScripts}

          touch $out
        '';
      }
      // (pkgs.lib.mergeAttrsList (pkgs.lib.mapAttrsToList (_: value: (value {inherit craneLib pkgs;}).checks) libraries))
      // (pkgs.lib.mergeAttrsList (pkgs.lib.mapAttrsToList (_: value: (value {inherit craneLib pkgs;}).checks) packages));
    packages.x86_64-linux = rec {
      coverage = let
        paths = pkgs.lib.mapAttrsToList (_: value: (value {inherit craneLib pkgs;}).coverage) (libraries // packages);
      in
        pkgs.runCommand "coverage" {} ("mkdir $out\n" + (pkgs.lib.concatStringsSep "\n" (builtins.map (p: "ln -s ${p} $out/${p.name}") paths)) + "\n");
      default = coverage;
    };
    devShells.x86_64-linux.default = pkgs.mkShell {
      DATABASE_URL = "postgres://ramona:@localhost/rad";
      packages = with pkgs; [
        alsaLib.dev
        cargo-leptos
        clang
        google-cloud-sdk
        lua-language-server
        nil
        pipewire
        pkg-config
        rust-analyzer
        stylua
        terraform
        terraform-ls
        trunk
        wasm-bindgen-cli
        udev.dev
        postgresql_16

        (pkgs.rust-bin.stable.latest.default.override {
          extensions = ["rust-src" "llvm-tools-preview"];
          targets = ["aarch64-unknown-linux-gnu" "wasm32-unknown-unknown"];
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

          (import ./modules/base.nix {inherit nixpkgs;})

          ./users/ramona.nix
          ./users/root.nix
          ./machines/hallewell/arrsuite.nix
          ./machines/hallewell/grafana.nix
          ./machines/hallewell/hardware.nix
          ./machines/hallewell/minio.nix
          ./machines/hallewell/nas.nix
          ./machines/hallewell/networking.nix
          ./machines/hallewell/paperless.nix
          ./machines/hallewell/postgresql.nix
          ./machines/hallewell/ras.nix
          ./machines/hallewell/ratweb.nix
          ./machines/hallewell/tempo.nix
          ./machines/hallewell/users/ramona.nix
          ./modules/bcachefs.nix
          ./modules/rad.nix
          ./modules/installed_base.nix
          ./modules/ras.nix
          ./modules/syncthing.nix
          ./modules/telegraf.nix
          ./modules/updates.nix
        ];
      };
      moonfall = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default

          (import ./modules/base.nix {inherit nixpkgs;})

          ./users/ramona/gui.nix
          ./users/ramona.nix
          ./users/root.nix
          ./machines/moonfall/hardware.nix
          ./machines/moonfall/networking.nix
          ./machines/moonfall/users/ramona_gui.nix
          ./machines/moonfall/virtualisation.nix
          ./modules/android-dev.nix
          ./modules/greetd.nix
          ./modules/installed_base.nix
          ./modules/rad.nix
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

          (import ./modules/base.nix {inherit nixpkgs;})

          ./users/ramona.nix
          ./users/root.nix
          ./machines/shadowmend/hardware.nix
          ./machines/shadowmend/home-automation.nix
          ./machines/shadowmend/networking.nix
          ./machines/shadowmend/rabbitmq.nix
          ./machines/shadowmend/users/ramona.nix
          ./machines/shadowmend/zigbee2mqtt.nix
          ./modules/bcachefs.nix
          ./modules/installed_base.nix
          ./modules/nas-client.nix
          ./modules/telegraf.nix
          ./modules/rad.nix
          ./modules/updates.nix
        ];
      };
      shadowsoul = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default

          (import ./modules/base.nix {inherit nixpkgs;})

          ./users/ramona.nix
          ./users/root.nix
          ./machines/shadowsoul/hardware.nix
          ./machines/shadowsoul/networking.nix
          ./machines/shadowsoul/transmission.nix
          ./modules/bcachefs.nix
          ./modules/installed_base.nix
          ./modules/nas-client.nix
          ./modules/telegraf.nix
          ./modules/rad.nix
          ./modules/updates.nix
        ];
      };
      angelsin = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default
          nixos-hardware.nixosModules.framework-13-7040-amd
          lanzaboote.nixosModules.lanzaboote

          (import ./modules/base.nix {inherit nixpkgs;})

          ./users/ramona/gui.nix
          ./users/ramona.nix
          ./users/root.nix
          ./machines/angelsin/hardware.nix
          ./machines/angelsin/networking.nix
          ./machines/angelsin/users/ramona_gui.nix
          ./machines/angelsin/virtual-screen.nix
          ./modules/android-dev.nix
          ./modules/greetd.nix
          ./modules/installed_base.nix
          ./modules/nas-client.nix
          ./modules/steam.nix
          ./modules/syncthing.nix
          ./modules/telegraf.nix
          ./modules/terraform-tokens.nix
          ./modules/updates.nix
          ./modules/rad.nix
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

          (import ./modules/base.nix {inherit nixpkgs;})
          (import ./machines/ananas/hardware.nix {inherit pkgsCross;})

          ./users/ramona.nix
          ./users/root.nix
          ./machines/ananas/music-control.nix
          ./machines/ananas/networking.nix
          ./modules/installed_base.nix
          ./modules/nas-client.nix
          ./modules/rad.nix
          ./modules/telegraf.nix
          ./modules/updates.nix
        ];
      };
      evillian = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        system = "x86_64-linux";
        modules = [
          lix-module.nixosModules.default
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default
          nixos-hardware.nixosModules.microsoft-surface-go
          lanzaboote.nixosModules.lanzaboote

          (import ./modules/base.nix {inherit nixpkgs;})

          ./machines/evillian/hardware.nix
          ./machines/evillian/networking.nix
          ./modules/greetd.nix
          ./modules/installed_base.nix
          ./modules/nas-client.nix
          ./modules/syncthing.nix
          ./modules/telegraf.nix
          ./modules/updates.nix
          ./modules/workstation.nix
          ./users/ramona.nix
          ./modules/rad.nix
          ./users/root.nix
          ./users/ramona/gui.nix
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

          (import ./modules/base.nix {inherit nixpkgs;})

          ./users/ramona.nix
          ./users/root.nix
          ./machines/caligari/github-runner.nix
          ./machines/caligari/hardware.nix
          ./machines/caligari/minecraft.nix
          ./machines/caligari/networking.nix
          ./machines/caligari/nginx.nix
          ./modules/rad.nix
          ./machines/caligari/telegraf.nix
          ./modules/bcachefs.nix
          ./modules/installed_base.nix
          ./modules/minecraft.nix
          ./modules/telegraf.nix
          ./modules/updates.nix
        ];
      };
      iso = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        system = "x86_64-linux";
        modules = [
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default

          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

          (import ./modules/base.nix {inherit nixpkgs;})

          ./users/ramona.nix
          ./users/root.nix
          ./modules/bcachefs.nix
          ./modules/iso.nix
        ];
      };
    };
  };
}
