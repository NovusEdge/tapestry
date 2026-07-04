# M0 Evaluation Gate Schema

Issue [#119](https://github.com/The-AI-Alliance/tapestry/issues/119) calls
for a minimally sufficient M0 evaluation framework before Tapestry commits to
a full benchmark stack. The first production artifact is the tool-neutral gate
schema in `tapestry.evaluation`.

The schema separates three concerns:

| Artifact | Purpose |
| :------- | :------ |
| `BenchmarkSpec` | Declares the benchmark, metric, threshold, evidence visibility, and whether it blocks release. |
| `EvaluationResult` | Records the score emitted by a benchmark runner such as `lm-evaluation-harness`, Unitxt, or a Tapestry-specific harness. |
| `EvaluationBundle` | Carries versioned runner output with the benchmark configuration hash that produced it. |
| `EvaluationGate` | Produces a deterministic go/no-go decision from specs and results. |

This lets the work group decide benchmark tools and task packaging separately
from release-gate semantics. It also gives future CI, infrastructure, and
certification work a stable result contract to target.

## Example

```python
from tapestry.evaluation import (
    BenchmarkKind,
    BenchmarkSpec,
    EvaluationBundle,
    EvaluationGate,
    EvaluationResult,
)

gate = EvaluationGate(
    [
        BenchmarkSpec(
            benchmark_id="capability-core",
            name="Core capability suite",
            kind=BenchmarkKind.CAPABILITY,
            metric="accuracy",
            threshold=0.62,
        ),
        BenchmarkSpec(
            benchmark_id="toxicity-rate",
            name="Safety toxicity rate",
            kind=BenchmarkKind.SAFETY,
            metric="rate",
            threshold=0.05,
            higher_is_better=False,
        ),
    ]
)

bundle = EvaluationBundle(
    config_hash=gate.config_hash,
    results=(
        EvaluationResult("capability-core", 0.64),
        EvaluationResult("toxicity-rate", 0.03),
    ),
)

decision = gate.decide_bundle(bundle)
assert decision.passed
```

## Near-Term Use

- Keep #119 benchmark selection discussions focused on concrete
  `BenchmarkSpec` entries.
- Require M0 runners to emit `EvaluationResult` records, regardless of the
  underlying tool.
- Include the gate's `config_hash` in each `EvaluationBundle`, so
  pre-registered thresholds and result bundles can be compared across member
  runs.
- Treat missing required results and threshold misses as blocking findings.
- Treat unexpected runner output as reportable but non-blocking, so experiments
  can include extra measurements without breaking the release gate.
