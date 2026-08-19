## Purpose

Defines the continuous-integration contract for the flake collection: which platforms every pull request and main-branch push MUST be verified on, which package outputs MUST be built and executed, and what runtime evidence CI MUST collect before merging.

## ADDED Requirements

### Requirement: CI runs on both supported systems
CI SHALL run on every pull request targeting `main` and every push to `main`, with jobs on both `x86_64-linux` (an `ubuntu-latest` GitHub runner) and `aarch64-darwin` (an arm64 `macos-*` GitHub runner, pinned to an explicit label, never `latest`). The macOS runner SHALL be arm64 because the flake declares `aarch64-darwin` as its only Darwin system.

#### Scenario: Pull request opened
- **WHEN** a pull request targeting `main` is opened or updated
- **THEN** CI jobs for both `x86_64-linux` and `aarch64-darwin` run against the pull request head

#### Scenario: Push to main
- **WHEN** a commit is pushed to `main`
- **THEN** CI jobs for both `x86_64-linux` and `aarch64-darwin` run

### Requirement: Every package output is built per platform
CI SHALL build every package named in an explicit `PACKAGES` list maintained in the workflow, for the runner's system; the list SHALL stay in sync with the flake's package set, so adding a package means a one-line workflow edit. As an evaluation backstop, `nix flake check` SHALL evaluate every package output on both lanes, so evaluation regressions (system asserts, platform/license metadata) are gated even before a new package's name reaches the list. Platform-independent outputs (fixed-output derivations whose content is byte-identical across systems, e.g. the circuit-parameter linkFarm) SHALL be built on the Linux lane only. The Linux lane SHALL run `nix flake check --all-systems` (evaluating the Darwin outputs from Linux); the macOS lane SHALL run `nix flake check`.

#### Scenario: New package added to the flake
- **WHEN** a pull request adds a new package to the flake outputs
- **THEN** `nix flake check` evaluates it on both lanes automatically, and it gains build and runtime verification once its name is added to the workflow's `PACKAGES` list

#### Scenario: Platform-independent output
- **WHEN** CI builds the circuit-parameter package
- **THEN** it is built and hash-verified on the Linux lane only, and the macOS lane skips it

#### Scenario: A derivation fails to evaluate or build for a supported system
- **WHEN** any listed package output fails to build on its lane
- **THEN** the CI job for that lane fails

### Requirement: Packaged binaries are executed and version-asserted
For each package that ships executable binaries, CI SHALL run those binaries from the built store output and SHALL assert that their reported version strings match the versions pinned in the corresponding package definition. For the circuit-parameter package, CI SHALL assert the built linkFarm exposes exactly the documented number of parameter files with the documented names.

#### Scenario: Toolchain version assert
- **WHEN** the `compact-toolchain` package is built
- **THEN** CI runs `compactc --version` and asserts the output contains the pinned toolchain version, and runs each other shipped binary at least once

#### Scenario: Devtool version assert
- **WHEN** the `compact-midnight` package is built
- **THEN** CI runs `compact --version` and asserts the output contains the pinned devtool version

#### Scenario: Circuit parameter completeness
- **WHEN** the circuit-parameter package is built on the Linux lane
- **THEN** CI asserts the linkFarm contains exactly the pinned parameter set (one file per named parameter, expected count)

#### Scenario: Binary fails to execute
- **WHEN** a packaged binary cannot execute on the runner (e.g. missing signature, wrong architecture)
- **THEN** the CI job fails at the version-assert step

### Requirement: End-to-end compile of a test circuit
CI SHALL compile a committed Compact test circuit (derived from Midnight documentation, with provenance attributed, compatible with the pinned compiler's language version) with the packaged `compactc` on every lane, and SHALL assert the compiler emits the documented artifact set: the TypeScript contract output, one zkir file per exported circuit, and one prover/verifier key pair per exported circuit. The test circuit SHALL contain at least one witness so that key generation is exercised.

#### Scenario: Successful end-to-end compile
- **WHEN** CI compiles the committed test circuit with the packaged `compactc` on a lane
- **THEN** the run asserts `contract/`, `zkir/`, and `keys/` artifacts exist for every exported circuit, and the job passes only if they do

#### Scenario: Key generation silently skipped
- **WHEN** the packaged toolchain emits no `zkir/` or `keys/` artifacts for the test circuit
- **THEN** the CI job fails

### Requirement: Format gate
The Linux CI lane SHALL verify that `nix fmt` produces no changes (`git diff --exit-code` after formatting).

#### Scenario: Unformatted Nix sources
- **WHEN** a pull request contains Nix files that `nix fmt` would modify
- **THEN** the Linux CI lane fails

### Requirement: CI uses the nix store cache
CI SHALL cache the nix store to the GitHub Actions cache service, keyed on the flake lock and the Nix package definitions, so repeated runs restore closures instead of rebuilding them.

#### Scenario: Repeated run with unchanged nix inputs
- **WHEN** CI runs again with unchanged `flake.lock` and `nix/**` definitions
- **THEN** the nix store closure is restored from the GitHub Actions cache rather than rebuilt or re-fetched from origin
