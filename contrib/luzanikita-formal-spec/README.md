# Tapestry formal specs (Quint) — `luzanikita-formal-spec`

Executable, machine-checkable models of Tapestry's load-bearing invariants
(see `docs/reference/ARCHITECTURE.md#design-goals-and-invariants`), sitting
between prose decisions (`docs/`) and implementation (`src/`).

**Motivation.** `ARCHITECTURE.md` says every design doc and PR "should be
checked against these invariants," but nothing enforces it. This contribution
formalizes the headline invariant (INV-1) as an executable Quint model so the
check becomes mechanical, and demonstrates the counterexample-driven workflow.

**Status.** Proof-of-concept pilot, staged here under `contrib/` per
[`CONTRIBUTING.md`](../../CONTRIBUTING.md). It accompanies the formal-specification
**proposal in issue #203**, which proposes promoting this to a top-level `spec/`
directory with a repo-wide coherence CI gate if the practice is adopted. Until
then it lives and runs entirely inside this directory.

**How to try it.** See [Running it](#running-it) below — `npm ci` then
`npm run spec:check` from this directory.

## Quint in ~6 concepts

| Concept | What it means here |
| :--- | :--- |
| **module** | A `.qnt` file's top-level namespace: `module shared { ... }`. Modules import one another (`import shared(NODES = Set(1,2,3)).* from "./shared"`). |
| **state (`var`)** | The system's mutable variables — e.g. `wire`, `sharedBase`, `knowledge`. |
| **action** | A guarded state transition (`action integrate: bool = all { guard, x' = ... }`). Disabled (returns `false`) when its guard doesn't hold. |
| **run** | `quint run` randomly simulates `step` from `init`, looking for an invariant violation. It's a sampler, not a proof — the deterministic complement is `run` *definitions* (test scenarios), executed via `quint test`. |
| **invariant** | A `val`-typed boolean that must hold in **every** reachable state, e.g. `no_raw_data_crosses`. |
| **nondet** | A non-deterministic pick (`nondet n = NODES.oneOf()`) — the simulator explores different choices across sampled traces. |

This project uses `quint run` only (random simulation) — not `quint verify`
(Apalache/exhaustive bounded model checking), which requires a Java runtime
that CI here does not have.

## Layout

```
contrib/luzanikita-formal-spec/
  consortium/
    shared.qnt          # types, state, "compliant" protocol actions, invariants
    compliant.qnt        # instantiates shared + a step — the honest protocol
    compliant_test.qnt   # deterministic quint-test scenarios
    leaky.qnt             # instantiates shared + adversarial actions — violates INV-1
  package.json            # pins the Quint CLI version for CI/local parity
  LICENSE                 # Apache-2.0 / CC-BY-4.0 / CDLA-2.0 (repo defaults)
```

**CI integration:** `.github/workflows/spec.yml` runs `make formal-spec-verify SPEC_DIR=contrib/luzanikita-formal-spec` to validate the pilot. Local and CI share this entry point via `.formal-spec.mk` (see top-level `Makefile`).

## The INV-1 pilot (`consortium/`)

Formalizes `ARCHITECTURE.md` INV-1 ("no raw data crosses node boundaries —
only model weight vectors after Contributed CPT"), INV-2 (portability / no
provider lock-in), and INV-3 (only Contributed CPT feeds the Shared Base).
See `consortium/shared.qnt`'s module comment for the full mapping to
ADR-002/004/005/006/008.

## Running it

**Recommended: use the top-level make targets** (aligned with CI):
```bash
# Install the pinned Quint toolchain
make formal-spec-install SPEC_DIR=contrib/luzanikita-formal-spec

# Typecheck + run invariants + tests (what CI uses)
make formal-spec-verify SPEC_DIR=contrib/luzanikita-formal-spec
```

**Or run manually** (same as what make does — installs Quint and runs `npm run spec:check`):
```bash
cd contrib/luzanikita-formal-spec
npm install

# Type-check every module
npm run typecheck

# The compliant protocol satisfies all three invariants (expect "No violation found")
npx quint run --invariant=no_raw_data_crosses consortium/compliant.qnt
npx quint run --invariant=only_cpt_feeds_base consortium/compliant.qnt
npx quint run --invariant=weights_portable consortium/compliant.qnt

# The leaky variant violates the headline invariant (expect a counterexample trace)
npx quint run --invariant=no_raw_data_crosses consortium/leaky.qnt

# Deterministic scenario tests
npx quint test consortium/compliant_test.qnt --main compliantTest
```

### Troubleshooting `npm install`/`npm ci`

- **`npm audit` reports a high-severity `adm-zip` vulnerability.** Quint 0.32.0
  depends on `adm-zip@^0.5.16`, which resolves to a version with a known
  advisory ([GHSA-xcpc-8h2w-3j85](https://github.com/advisories/GHSA-xcpc-8h2w-3j85));
  upstream Quint hasn't bumped that range to the patched `0.6.0` yet.
  `package.json` pins `adm-zip` to `^0.6.0` via `overrides` to close this
  without downgrading Quint. **Don't run `npm audit fix --force`** — it can't
  see the override and will instead offer to downgrade Quint to `0.23.1` (a
  real breaking change), since that's the only vulnerability-free version
  resolvable *without* an override. A clean `npm ci` should report
  `found 0 vulnerabilities`; if it doesn't, check that `package-lock.json` is
  up to date with the `overrides` entry (`npm install` regenerates it).
- **`npm warn allow-scripts ... protobufjs@... postinstall`** (or similar
  install-script warnings) come from script-allowlisting tooling/policy on
  your own npm setup, not from anything in this repo (there's no `postinstall`
  script here). It's informational only and doesn't block the install.

## Reading a violation (and what to do about it)

A `quint run`/`quint verify` failure prints a **counterexample**: the shortest
sequence of states (`[State 0] … [State N]`) that reaches an invariant breach.
Read it back-to-front — the **last state** is the breach; the diff from the
previous state is the **action that caused it**. Example from `leaky.qnt`:

```
[State 0]  wire: Set()                                   # start: nothing transmitted
[State 1]  wire: Set(RawData({ node: 2, token: 201 }))   # node 2 put RAW data on the wire
[violation] Invariant violated   (no_raw_data_crosses)
```

Interpretation: a `RawData` item appeared on the `wire`, so `no_raw_data_crosses`
(INV-1) fails — node 2 leaked raw sample `201`. Re-run with the printed
`--seed=…` to reproduce the exact trace; add `--verbosity=3` to see which action
fired.

A violation is **not automatically a code bug** — it forces an explicit choice
among three actionable outcomes:

1. **Fix the system.** The design/implementation genuinely allows the bad
   behavior → change the protocol/code so the offending action can't happen
   (e.g., nodes only ever emit `CptWeights`, never `RawData`). This is the case
   the `leaky` variant demonstrates by construction — its Byzantine
   `leakyGossipRawData` action is the defect the invariant is meant to catch.
2. **Fix the property.** The invariant is stronger/wrong than intended and
   forbids something legitimate → correct or weaken it in `shared.qnt` (and say
   why in the commit).
3. **Add a missing assumption/constraint.** The model permits a state the real
   system actually prevents (an action that can't occur in practice) → encode
   that guard/precondition in the spec — **and** confirm the real system
   enforces it, otherwise outcome 1 applies.

Every counterexample therefore ends in a recorded decision about either our
**code** or our **stated constraints/assumptions**. A clean `compliant.qnt` run
is the same statement in the positive — no sequence of modeled actions reaches
the breach (remembering that `quint run` samples rather than proves; `quint
verify` upgrades a clean result to a bounded proof).

## License

This contribution follows the repository default licenses (see [`LICENSE`](LICENSE)):

- Code: Apache License, Version 2.0.
- Documentation: Creative Commons Attribution 4.0 International.
- Data, if added later: CDLA Permissive 2.0.
