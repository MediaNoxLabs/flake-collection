## 1. Test fixture

- [x] 1.1 Add `test/lock.compact` with an Apache-2.0 attribution header crediting `midnightntwrk/midnight-docs` (writing guide's `lock.compact`), pragma `language_version 0.23` to match compactc 0.31.1
- [x] 1.2 Verify locally: `nix build .#compact-toolchain` then compile the fixture and confirm `zkir/*.zkir`, `keys/*.prover|verifier` per exported circuit, and `contract/index.js` are emitted

## 2. CI workflow

- [x] 2.1 Create `.github/workflows/ci.yml`: name, `on: pull_request/push → main`, `permissions: contents: read`, `strategy.matrix.os: [ubuntu-latest, macos-15]` (fail-fast disabled)
- [x] 2.2 Steps: `actions/checkout@v4` → `DeterminateSystems/nix-installer-action@v4` → `nix-community/cache-nix-action@v7` (`primary-key: nix-${{ runner.os }}-packages-${{ hashFiles('flake.lock', 'flake.nix', 'nix/**/*.nix') }}`, `restore-prefixes-first-match: nix-${{ runner.os }}-packages-`, `gc-max-store-size-linux: 7500M`, `gc-max-store-size-macos: 7500M`)
- [x] 2.3 Linux-only prelude step: `nix fmt` then `git diff --exit-code`
- [x] 2.4 Build step: iterate an explicit `PACKAGES` list (job env) with one `nix build .#<name>` per package; exclude `midnight-circuit-params` on macOS; capture store paths into env vars via `--print-out-paths` (revised from dynamic `nix flake show --json` discovery after Determinate Nix 3.x's `inventory` schema broke it — see design decision 2)
- [x] 2.5 Smoke + asserts step: run `compactc --version`, `fixup-compact --help`, `format-compact --help` from the toolchain output; run `compact --version`. Expected versions are derived at runtime via `nix eval .#<pkg>.version` (not hardcoded) and matched as a literal whole word in bash (rejects `0.31.10`, `0.31.1-rc2`)
- [x] 2.6 Linux-only params assert: the linkFarm output contains exactly the 19 expected `bls_midnight_2p*` entries
- [x] 2.7 E2e step (both lanes): compile `test/lock.compact` twice — with the packaged `compactc` directly and through the `compact` devtool (`COMPACT_DIRECTORY=… compact compile`, exercising the symlink-target compiler discovery) — into temp dirs; assert `contract/index.js`, `zkir/{get,set,clear}.zkir` (+ `.bzkir`), and `keys/{get,set,clear}.{prover,verifier}` all exist in both outputs. On Linux the param cache is pre-seeded from the linkFarm and a name+type snapshot must be unchanged after the compiles
- [x] 2.8 Flake check step: `nix flake check --all-systems` on Linux, `nix flake check` on macOS

## 3. Delivery

- [x] 3.1 Open feature branch (`ci/add-workflow`) and pull request; confirm both matrix lanes run and pass on the PR itself
- [x] 3.2 Update `README.md` development section to mention CI coverage (both systems, e2e compile)
