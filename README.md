# flake-collection

A reusable Nix flake collection packaging tools from the
[Midnight](https://midnight.network/) ecosystem.

## Packages

| Package | Version | Provides |
| --- | --- | --- |
| `compact-toolchain` | 0.31.1 | `compactc`, `fixup-compact`, `format-compact` and the `COMPACT_DIRECTORY` layout |
| `compact-midnight` | 0.5.1 | `compact` — the Compact devtool CLI |

Supported systems: `x86_64-linux`, `aarch64-darwin`.

## Consuming

Add this flake as an input in your `flake.nix`:

```nix
inputs.flake-collection.url = "github:MediaNoxLabs/flake-collection";
```

Run a tool directly:

```sh
nix run github:MediaNoxLabs/flake-collection#compact-midnight -- --help
```

Build the compiler toolchain and invoke `compactc`:

```sh
nix build github:MediaNoxLabs/flake-collection#compact-toolchain
./result/bin/compactc --version
```

Or pull packages through `flake-parts` in a downstream `perSystem`:

```nix
{ inputs', ... }: {
  perSystem = { pkgs, ... }: {
    devShells.default = pkgs.mkShell {
      packages = [
        inputs'.flake-collection.packages.compact-toolchain
        inputs'.flake-collection.packages.compact-midnight
      ];
    };
  };
}
```

## Development

```sh
nix develop     # shell with nixfmt + tooling
nix fmt         # format Nix sources
nix flake check # validate the flake
```

## License

Apache-2.0, matching the upstream [compact](https://github.com/midnightntwrk/compact)
toolchain.
