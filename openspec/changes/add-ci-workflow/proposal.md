## Why

The flake packages prebuilt Midnight binaries for `x86_64-linux` and `aarch64-darwin`, but nothing verifies those outputs: the darwin derivations have never been built (this repository has no macOS CI), and the Linux outputs have never had their binaries smoke-run or end-to-end tested. A repackaging repository's core promise is "these binaries work from the store", so breakage (upstream re-tagging, signature/wrapper changes, hash drift) is currently invisible until a consumer hits it.

## What Changes

- Add `.github/workflows/ci.yml`: a matrix CI over `ubuntu-latest` (x86_64-linux) and `macos-15` (aarch64-darwin) that builds, verifies, and smoke-runs every flake package output.
- Build every package named in an explicit `PACKAGES` list in the workflow (kept in sync with the flake's package set; `nix flake check` still evaluates new packages on both lanes as a backstop).
- Gate the build with runtime verification: version-string asserts on `compactc`/`compact`, a linkFarm entry-count assert (19 circuit-param files), and an end-to-end `compactc` compile of a committed test circuit asserting `zkir/`, `keys/`, and `contract/` artifacts.
- Build platform-independent outputs (`midnight-circuit-params`) on the Linux lane only; run the end-to-end compile on both lanes (platform-dependent binaries).
- Format gate on the Linux lane: `nix fmt` must be a no-op (`git diff --exit-code`).
- Nix store caching via `nix-community/cache-nix-action@v7` keyed on `hashFiles('flake.lock', 'nix/**/*.nix')`, mirroring `input-output-hk/lace-id-portal`'s CI.
- Deliver via a feature branch and pull request.

## Capabilities

### New Capabilities

- `ci`: Continuous-integration behavior of the repository — what must be verified per platform, how packages are selected, what runtime asserts are required, and when lint/format checks gate.

### Modified Capabilities

(none — no existing specs; `ci` is the first capability in this repository)

## Impact

- New files: `.github/workflows/ci.yml`, `test/lock.compact` (test fixture derived from `midnightntwrk/midnight-docs`, Apache-2.0 attribution header).
- No changes to `flake.nix`, `nix/**`, or any package definition — CI observes, never modifies, the packages.
- CI runtime cost: ~200 MB of circuit-param fetches on the Linux lane (first run per cache key only); macOS lane downloads the two toolchain artifacts (~35 MB) plus nix store closures; the e2e compile fetches ~1.6 MB of small circuit params and finishes in ~15 s.
