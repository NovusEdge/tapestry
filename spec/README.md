# Tapestry formal specs (Quint)

Executable, machine-checkable models of Tapestry's load-bearing invariants
(see `docs/reference/ARCHITECTURE.md#design-goals-and-invariants`), sitting
between prose decisions (`docs/`) and implementation (`src/`).

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
spec/
  consortium/
    shared.qnt          # types, state, "compliant" protocol actions, invariants
    compliant.qnt        # instantiates shared + a step — the honest protocol
    compliant_test.qnt   # deterministic quint-test scenarios
    leaky.qnt             # instantiates shared + adversarial actions — violates INV-1
  package.json            # pins the Quint CLI version for CI/local parity
```

## The INV-1 pilot (`consortium/`)

Formalizes `ARCHITECTURE.md` INV-1 ("no raw data crosses node boundaries —
only model weight vectors after Contributed CPT"), INV-2 (portability / no
provider lock-in), and INV-3 (only Contributed CPT feeds the Shared Base).
See `consortium/shared.qnt`'s module comment for the full mapping to
ADR-002/004/005/006/008.

## Running it

```bash
cd spec
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

`npm run spec:check` runs the typecheck + compliant-invariant steps CI uses.

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
