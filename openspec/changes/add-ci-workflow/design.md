## Context

The repository packages three prebuilt Midnight binaries (`compact-toolchain` 0.31.1, `compact-midnight` 0.5.1, `midnight-circuit-params`) via flake-parts for `x86_64-linux` and `aarch64-darwin`. Nothing currently verifies these outputs in CI: the repository has no `.github/` directory at all, and the darwin derivations have never been built anywhere. The repository is public (`MediaNoxLabs/flake-collection`), so GitHub-hosted runners (including free arm64 macOS for public repos) are available. The reference CI pattern is `input-output-hk/lace-id-portal` (private; `ci.yml` + `macos-devshell.yml`): DeterminateSystems/nix-installer-action@v4, nix-community/cache-nix-action@v7 keyed on `hashFiles('flake.lock', 'Cargo.lock', 'nix/**/*.nix')`, `macos-14` for arm64.

Facts established during planning (measured locally on x86_64-linux): the Linux packages build and run; `compactc --version` prints `0.31.1` and `compact --version` prints `compact 0.5.1`; a witness-bearing test circuit (`lock.compact` from Midnight's writing guide, pragma bumped `0.16` → `0.23`) compiles in ~13 s, emitting `contract/index.js`, `zkir/{get,set,clear}.zkir` (+ `.bzkir`), and `keys/{get,set,clear}.{prover,verifier}`, while fetching only ~1.6 MB of small circuit params (`bls_midnight_2p6`, `bls_midnight_2p13`) into `~/.cache/midnight/zk-params`. Param sizes double per k-level: the whole linkFarm is ~192 MB with `2p19` alone ~96 MB. All darwin binaries are arm64 Mach-O with embedded code signatures, and the `substituteInPlace --replace-fail` target string exists verbatim in the darwin `compactc` wrapper.

## Goals / Non-Goals

**Goals:**
- Prove, per supported platform, that every flake package output builds and its binaries execute with the pinned versions.
- Prove the toolchain end-to-end (zkir + key generation) on both platforms' binaries.
- Keep CI self-maintaining: new packages are *evaluated* without workflow edits (via `nix flake check`); build + smoke coverage begins with a one-line `PACKAGES` list edit (see Decision 2).

**Non-Goals:**
- Changing any package definition, version, or the parameter set (2p1–2p19 stays; trimming was rejected as a CI-cost measure in favor of lane-level exclusion).
- Devshell verification (`nix develop`) — the devshell is trivial (`nixfmt` + `git`).
- Docker/compose integration, publish/artifact upload to releases, or Cachix pushing.

## Decisions

1. **Single workflow file with a runner matrix, not one file per platform.** The reference repo splits `ci.yml`/`macos-devshell.yml` only because a workflow-level Linux-only `RUSTFLAGS` would poison its macOS job; we have no such divergence, so a matrix (`strategy.matrix.os: [ubuntu-latest, macos-15]`) avoids copy-paste drift. `macos-15` (arm64) is pinned explicitly — `macos-latest` could silently flip architecture; `macos-14` (the reference's pin) would also work.

2. **Explicit `PACKAGES` list in the workflow, not `nix flake show` discovery.** The first implementation enumerated packages by parsing `nix flake show --json`; it broke on the CI runners' Determinate Nix 3.x, which renders a new `inventory` schema (`.inventory.packages.output.children.<system>.children`) instead of the legacy `.packages.<system>` map — a presentation layer that drifts across Nix versions is exactly the hidden maintenance burden CI should not carry. The workflow instead iterates an explicit `PACKAGES` list with plain `nix build .#<name>`. `nix flake check` (final step, both lanes) still evaluates every package output, so evaluation regressions in not-yet-listed packages are gated; build and runtime coverage for a new package begins with a one-line list edit. (Verified empirically: `nix flake check` builds only the `checks` output — it evaluates but does not build `packages.*`; fully automatic build gating would require mirroring packages into `checks`, which would modify `nix/`, out of scope here.) The circuit-param linkFarm is excluded from the macOS lane's build set because its fixed-output derivations are byte-identical across platforms — Linux building them proves hashes and URLs.

3. **Version-string asserts after build.** Build success says nothing about whether upstream shipped the right artifact. CI runs each shipped binary and greps its `--version` output for the pinned version. On hash mismatch (upstream re-tag) the build fails first with a hash error; the version assert catches subtler wrong-artifact-in-right-bucket cases.

4. **E2e compile via a committed fixture, not a fetched one.** `test/lock.compact` is committed with an Apache-2.0 attribution header to `midnightntwrk/midnight-docs` (same license as this repo), pragma pinned to `0.23` for compactc 0.31.1. The fixture must contain a witness (an empty/trivial circuit compiles but silently skips zkir and key generation — verified empirically); CI therefore asserts the `zkir/` and `keys/` artifact sets per exported circuit, which specifically catches the silent-skip failure mode. Runs on both lanes: the musl and darwin binaries are independent upstream builds.

5. **LinkFarm entry-count assert on Linux.** After building `midnight-circuit-params`, CI asserts the output directory contains exactly the 19 expected `bls_midnight_2p*` names — catches upstream dropping/renaming a param file while hashes still match per-file.

6. **Store cache mirrors the reference.** `nix-community/cache-nix-action@v7` with `primary-key: nix-${{ runner.os }}-packages-${{ hashFiles('flake.lock', 'nix/**/*.nix') }}`, `restore-prefixes-first-match`, `gc-max-store-size-linux/macos: 7500M`. Main payoff is the macOS lane (apple-sdk/cctools/clang closure ~1.3 GiB unpacked); GitHub's 10 GB cache budget is free for public repos.

7. **Format gate as a `nix fmt` + `git diff --exit-code` step on the Linux lane only.** The formatter (`nixfmt-tree`) is platform-independent, so gating once suffices.

8. **Delivery via feature branch → PR.** `pull_request` triggers give the workflow its own first run on the PR that adds it (after merging, branch protection can require it — out of scope here).

## Risks / Trade-offs

- [First run per cache key downloads ~200 MB (Linux) / ~265 MiB closures (macOS)] → accepted; steady-state PRs restore from GitHub Actions cache; eviction is LRU and self-healing.
- [E2e compile fetches ~1.6 MB of params from Midnight's S3 bucket at run time] → resolved on the Linux lane: the compile step pre-seeds `~/.cache/midnight/zk-params` from the already-built linkFarm (copying symlinks, not dereferencing ~200 MB) and asserts afterwards that the cache did not grow, so a fetch is a hard failure. The macOS lane still fetches (README documents the same behavior for humans); a bucket outage fails it loudly rather than masking breakage.
- [New package not on the list ships without build coverage] → guarded: the build step first diffs `PACKAGES` against `nix eval .#packages.<system>` attrNames (a stable eval API, unlike the `flake show` presentation layer rejected in Decision 2) and fails on drift, so the list cannot lag silently.
- [macos-15 arm64 runner image drift] → pinned label keeps architecture stable; image content changes are absorbed by the nix store cache.
- [Upstream compactc wrapper drift breaks `substituteInPlace --replace-fail`] → the build fails loudly on the lane that regressed; that is the desired signal, not a flake.

## Migration Plan

One PR adds `.github/workflows/ci.yml` and `test/lock.compact`; no existing behavior changes. Rollback = delete the workflow file.
