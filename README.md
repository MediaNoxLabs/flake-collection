# flake-collection

A reusable Nix flake collection packaging tools from the
[Midnight](https://midnight.network/) ecosystem.

## Packages

| Package | Version | Provides |
| --- | --- | --- |
| `compact-toolchain` | 0.31.1 | `compactc`, `fixup-compact`, `format-compact` and the `COMPACT_DIRECTORY` layout |
| `compact-midnight` | 0.5.1 | `compact` — the Compact devtool CLI |
| `midnight-circuit-params` | 19 param sets | Hash-pinned zkir circuit parameters (`bls_midnight_2p1`–`bls_midnight_2p19`) for offline compilation of circuits up to k=19 |

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

Pre-populate the zkir circuit-parameter cache so `compactc` does not
fetch parameters over the network for circuits up to k=19:

```sh
nix build github:MediaNoxLabs/flake-collection#midnight-circuit-params
mkdir -p ~/.cache/midnight/zk-params
# -L dereferences the linkFarm's symlinks into /nix/store so real files
# land in the cache; -n keeps entries already present. Both flags work
# with GNU and BSD cp.
cp -RLn result/* ~/.cache/midnight/zk-params/
```

The package pins `bls_midnight_2p1`–`bls_midnight_2p19` (~200 MB). The
compact toolchain references parameters up to `bls_midnight_2p25`
(~12.5 GB additionally), so compiling circuits larger than k=19 still
requires a network fetch unless `MIDNIGHT_PARAM_SOURCE` points at a
mirror that serves them.

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

## Continuous integration

Pull requests and pushes to `main` run CI on both supported systems
(`ubuntu-latest` for `x86_64-linux`, `macos-15` for `aarch64-darwin`). Every
flake package is built — the workflow's `PACKAGES` list is checked against the
flake's actual package set on every run, so it cannot lag — and built binaries
are executed with version assertions against the pins. The Linux lane
additionally verifies that `nix fmt` is a no-op and that the
`midnight-circuit-params` linkFarm contains the full 19-entry parameter set.
Both lanes compile `test/lock.compact` end-to-end with the packaged `compactc`,
asserting the emitted `contract/`, `zkir/`, and `keys/` artifacts. The Linux
lane pre-seeds its param cache from the built linkFarm (so that compile makes
no network fetch); on macOS the compile fetches the small circuit parameters it
needs over the network unless `~/.cache/midnight/zk-params` is pre-seeded
(see above).

## License

Apache-2.0, matching the upstream [compact](https://github.com/midnightntwrk/compact)
toolchain.
