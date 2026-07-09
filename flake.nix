{
  description = "Custom NixOS installer image for Raspberry Pi 5";

  inputs = {
    # main считается стабильной веткой в README nixos-raspberrypi
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    # Если хочешь прямо как в upstream latest/develop, можно заменить на:
    # nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/develop";
  };

  nixConfig = {
    # Важно: иначе можешь начать собирать kernel/firmware сам.
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];

    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = inputs@{ self, nixos-raspberrypi, ... }:
    let
      sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOo4nF0h5/eNCefAwb9lZPGV646OlHOJaxyROeW7fDnJ agmitron@macbook";

      customUserConfig = { config, pkgs, ... }: {
        users.users.nixos.openssh.authorizedKeys.keys = [
          sshKey
        ];

        users.users.root.openssh.authorizedKeys.keys = [
          sshKey
        ];

        users.users.agmitron = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
          ];
          openssh.authorizedKeys.keys = [
            sshKey
          ];
        };

        security.sudo.wheelNeedsPassword = false;

        environment.systemPackages = with pkgs; [
          git
          vim
          htop
          tree
          tmux
		  lsof
        ];

        networking.hostName = "pi";
        networking.firewall.allowedTCPPorts = [ 22 ];

        services.avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
          publish = {
            enable = true;
            addresses = true;
            workstation = true;
          };
        };

        system.stateVersion = "25.11";

        system.nixos.tags =
          let
            cfg = config.boot.loader.raspberry-pi;
          in
          [
            "raspberry-pi-${cfg.variant}"
            cfg.bootloader
            config.boot.kernelPackages.kernel.version
          ];
      };
    in
    {
      nixosConfigurations.rpi5-installer =
        nixos-raspberrypi.lib.nixosInstaller {
          specialArgs = inputs // {
            nixos-raspberrypi = nixos-raspberrypi;
          };

          modules = [
            ({ nixos-raspberrypi, ... }: {
              imports = with nixos-raspberrypi.nixosModules; [
                raspberry-pi-5.base

                # Upstream installer для RPi5 тоже включает это.
                raspberry-pi-5.page-size-16k
              ];
            })

            customUserConfig
          ];
        };

      nixosConfigurations.rpi5 =
        nixos-raspberrypi.lib.nixosSystem {
          specialArgs = inputs // {
            nixos-raspberrypi = nixos-raspberrypi;
          };

          modules = [
            ({ nixos-raspberrypi, ... }: {
              imports = with nixos-raspberrypi.nixosModules; [
                raspberry-pi-5.base
                raspberry-pi-5.bluetooth
                raspberry-pi-5.page-size-16k
                sd-image
              ];

              boot.loader.raspberry-pi.bootloader = "kernel";
            })

            ({ config, pkgs, lib, ... }: {
              nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

              networking.hostName = "pi";
              networking.networkmanager.enable = true;
              networking.firewall.allowedTCPPorts = [ 22 ];

              time.timeZone = "Asia/Tbilisi";

              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];

              users.users.agmitron = {
                isNormalUser = true;
                extraGroups = [
                  "wheel"
                  "networkmanager"
                ];

                openssh.authorizedKeys.keys = [
                  sshKey
                ];
              };

              security.sudo.wheelNeedsPassword = false;

              users.groups.media = { };

              users.users.navidrome.extraGroups = [ "media" ];

              services.openssh = {
                enable = true;
                openFirewall = true;
                settings = {
                  PasswordAuthentication = false;
                  PermitRootLogin = "prohibit-password";
                };
              };

              services.avahi = {
                enable = true;
                nssmdns4 = true;
                openFirewall = true;
                publish = {
                  enable = true;
                  addresses = true;
                  workstation = true;
                };
              };

              systemd.tmpfiles.rules = [
                "d /srv 2770 filebrowser media - -"
                "d /srv/music 2770 filebrowser media - -"
              ];

              system.activationScripts.musicPermissions = {
                deps = [ "users" ];
                text = ''
                  if [ -d /srv ]; then
                    ${pkgs.coreutils}/bin/chgrp media /srv
                    ${pkgs.coreutils}/bin/chmod 2770 /srv
                  fi

                  if [ -d /srv/music ]; then
                    ${pkgs.coreutils}/bin/chgrp -R media /srv/music
                    ${pkgs.findutils}/bin/find /srv/music -type d -exec ${pkgs.coreutils}/bin/chmod 2770 {} +
                    ${pkgs.findutils}/bin/find /srv/music -type f -exec ${pkgs.coreutils}/bin/chmod 660 {} +
                  fi
                '';
              };

              services.filebrowser = {
                enable = true;
                openFirewall = true;

                settings = {
                  address = "0.0.0.0";
                  port = 8081;
                  root = "/srv/";
                  database = "/var/lib/filebrowser/filebrowser.db";
                };
              };

              systemd.services.filebrowser.serviceConfig = {
                UMask = lib.mkForce "0027";
              };

              services.navidrome = {
                enable = true;
                openFirewall = true;

                settings = {
                  Address = "0.0.0.0";
                  Port = 4533;
                  MusicFolder = "/srv/music";
                };
              };

              systemd.services.navidrome.serviceConfig.SupplementaryGroups = [ "media" ];

              environment.systemPackages = with pkgs; [
                git
                vim
                htop
                tree
                tmux
                curl
                wget
              ];

              system.stateVersion = "25.11";

              system.nixos.tags =
                let
                  cfg = config.boot.loader.raspberry-pi;
                in
                [
                  "raspberry-pi-${cfg.variant}"
                  cfg.bootloader
                  config.boot.kernelPackages.kernel.version
                ];
            })
          ];
        };

      packages.aarch64-linux.rpi5-installer-image =
        self.nixosConfigurations.rpi5-installer.config.system.build.sdImage;

      packages.aarch64-linux.rpi5-image =
        self.nixosConfigurations.rpi5.config.system.build.sdImage;

      packages.aarch64-linux.default =
        self.packages.aarch64-linux.rpi5-image;
    };
}
