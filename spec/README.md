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
