# Raspberry Pi 5 NixOS Images

This flake contains two Raspberry Pi 5 outputs:

- `rpi5-installer`: mutable installer image
- `rpi5`: final NixOS system image

The final system is configured with hostname `pi` and user `agmitron`.

## Build The Installer Image

```sh
nix --accept-flake-config build .#packages.aarch64-linux.rpi5-installer-image
```

The compressed image will be at:

```sh
result/sd-image/nixos-image-rpi5-kernel.img.zst
```

## Build The Final Image

```sh
nix --accept-flake-config build .#packages.aarch64-linux.rpi5-image
```

The compressed image will be at:

```sh
result/sd-image/nixos-image-rpi5-kernel.img.zst
```

## Decompress The Image

Some flashing tools support `.zst` directly, but using a plain `.img` avoids ambiguity.

```sh
zstd -d -f result/sd-image/nixos-image-rpi5-kernel.img.zst -o nixos-rpi5-final.img
```

If `zstd` is missing on macOS:

```sh
brew install zstd
```

Flash this file to the SD card:

```sh
nixos-rpi5-final.img
```

## Connect To The Pi

After boot, try mDNS first:

```sh
ssh agmitron@pi.local
```

If mDNS does not resolve, find the IP from your router or ARP table and connect by IP:

```sh
ssh agmitron@192.168.0.186
```

## Update The Running Pi

Use the update script from this repository on the Mac:

```sh
scripts/update-pi
```

By default it uses:

```text
TARGET_HOST=pi.local
FLAKE_ATTR=rpi5
```

If `pi.local` does not resolve, pass the IP:

```sh
TARGET_HOST=192.168.0.186 scripts/update-pi
```

To update a different NixOS configuration attr:

```sh
FLAKE_ATTR=rpi5 TARGET_HOST=pi.local scripts/update-pi
```

## What The Update Script Does

The script is a manual equivalent of `nixos-rebuild switch --target-host`:

```sh
nix --accept-flake-config build .#nixosConfigurations.rpi5.config.system.build.toplevel
```

Then it exports the full closure from the local Nix store and imports it on the Pi as root:

```sh
nix-store --export $(nix-store --query --requisites ./result) \
  | ssh pi.local 'sudo nix-store --import'
```

Then it switches the system profile and activates the new configuration:

```sh
sudo nix-env -p /nix/var/nix/profiles/system --set /nix/store/...-nixos-system-pi-...
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

This avoids depending on `nixos-rebuild` on macOS.

## Useful Checks

Show flake outputs:

```sh
nix flake show
```

Check that `pi.local` resolves:

```sh
ping pi.local
```

Check SSH:

```sh
ssh agmitron@pi.local
```
