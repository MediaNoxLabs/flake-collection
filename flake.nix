{
  description = "Reusable Nix flake collection for the Midnight ecosystem (compact, compactc, ...)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./nix/packages
        ./nix/devshells
      ];

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        { system, ... }:
        {
          # Re-import nixpkgs with allowUnfree so the collection can ship
          # unrestricted binaries (e.g. future zkir packaging). Mirrors the
          # midnight-did toolchain setup.
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        };
    };
}
