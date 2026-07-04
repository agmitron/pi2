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
        ];

        networking.hostName = "pi";
        networking.firewall.allowedTCPPorts = [ 22 ];

        services.avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
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

      packages.aarch64-linux.rpi5-installer-image =
        self.nixosConfigurations.rpi5-installer.config.system.build.sdImage;

      packages.aarch64-linux.default =
        self.packages.aarch64-linux.rpi5-installer-image;
    };
}
