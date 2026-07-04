"""Tests for tool-neutral evaluation gates."""

from __future__ import annotations

import unittest

from tapestry.evaluation import (
    BenchmarkKind,
    BenchmarkSpec,
    EvaluationBundle,
    EvaluationGate,
    EvaluationResult,
    GateStatus,
    benchmark_config_hash,
)


class EvaluationGateTest(unittest.TestCase):
    def test_gate_passes_when_required_scores_meet_thresholds(self) -> None:
        gate = EvaluationGate(
            [
                BenchmarkSpec(
                    benchmark_id="mmlu-lite",
                    name="MMLU Lite",
                    kind=BenchmarkKind.CAPABILITY,
                    metric="accuracy",
                    threshold=0.62,
                ),
                BenchmarkSpec(
                    benchmark_id="toxicity-rate",
                    name="Toxicity Rate",
                    kind=BenchmarkKind.SAFETY,
                    metric="rate",
                    threshold=0.05,
                    higher_is_better=False,
                ),
            ]
        )

        decision = gate.decide(
            [
                EvaluationResult("mmlu-lite", 0.64),
                EvaluationResult("toxicity-rate", 0.03),
            ]
        )

        self.assertTrue(decision.passed)
        self.assertEqual(
            [finding.status for finding in decision.findings],
            [GateStatus.PASS, GateStatus.PASS],
        )
        self.assertEqual(decision.blocking_findings, ())

    def test_gate_blocks_missing_required_benchmark(self) -> None:
        gate = EvaluationGate(
            [
                BenchmarkSpec(
                    benchmark_id="cultural-alignment-smoke",
                    name="Cultural Alignment Smoke Test",
                    kind=BenchmarkKind.CULTURAL_ALIGNMENT,
                    metric="agreement",
                    threshold=0.7,
                )
            ]
        )

        decision = gate.decide([])

        self.assertFalse(decision.passed)
        self.assertEqual(decision.blocking_findings[0].status, GateStatus.MISSING)

    def test_optional_benchmark_is_not_required_to_pass_gate(self) -> None:
        gate = EvaluationGate(
            [
                BenchmarkSpec(
                    benchmark_id="domain-extra",
                    name="Domain Extra",
                    kind=BenchmarkKind.DOMAIN,
                    metric="accuracy",
                    threshold=0.8,
                    required=False,
                )
            ]
        )

        decision = gate.decide([])

        self.assertTrue(decision.passed)
        self.assertEqual(decision.findings, ())

    def test_gate_reports_unexpected_results_without_blocking(self) -> None:
        gate = EvaluationGate(
            [
                BenchmarkSpec(
                    benchmark_id="capability-core",
                    name="Capability Core",
                    kind=BenchmarkKind.CAPABILITY,
                    metric="accuracy",
                    threshold=0.6,
                )
            ]
        )

        decision = gate.decide(
            [
                EvaluationResult("capability-core", 0.7),
                EvaluationResult("unknown-runner-output", 1.0),
            ]
        )

        self.assertTrue(decision.passed)
        self.assertEqual(decision.findings[-1].status, GateStatus.UNEXPECTED)

    def test_duplicate_specs_and_results_are_rejected(self) -> None:
        spec = BenchmarkSpec(
            benchmark_id="capability-core",
            name="Capability Core",
            kind=BenchmarkKind.CAPABILITY,
            metric="accuracy",
            threshold=0.6,
        )

        with self.assertRaisesRegex(ValueError, "duplicate benchmark specs"):
            EvaluationGate([spec, spec])

        gate = EvaluationGate([spec])
        with self.assertRaisesRegex(ValueError, "duplicate benchmark results"):
            gate.decide(
                [
                    EvaluationResult("capability-core", 0.7),
                    EvaluationResult("capability-core", 0.8),
                ]
            )

    def test_config_hash_is_stable_across_spec_order(self) -> None:
        capability = BenchmarkSpec(
            benchmark_id="capability-core",
            name="Capability Core",
            kind=BenchmarkKind.CAPABILITY,
            metric="accuracy",
            threshold=0.6,
        )
        safety = BenchmarkSpec(
            benchmark_id="toxicity-rate",
            name="Toxicity Rate",
            kind=BenchmarkKind.SAFETY,
            metric="rate",
            threshold=0.05,
            higher_is_better=False,
        )

        first_hash = benchmark_config_hash([capability, safety])
        second_hash = benchmark_config_hash([safety, capability])

        self.assertEqual(first_hash, second_hash)
        self.assertEqual(len(first_hash), 64)

    def test_gate_decides_versioned_bundle_with_matching_config_hash(self) -> None:
        spec = BenchmarkSpec(
            benchmark_id="capability-core",
            name="Capability Core",
            kind=BenchmarkKind.CAPABILITY,
            metric="accuracy",
            threshold=0.6,
        )
        gate = EvaluationGate([spec])
        bundle = EvaluationBundle(
            results=(EvaluationResult("capability-core", 0.7),),
            config_hash=gate.config_hash,
        )

        decision = gate.decide_bundle(bundle)

        self.assertTrue(decision.passed)
        self.assertEqual(decision.findings[0].status, GateStatus.PASS)

    def test_gate_blocks_bundle_with_mismatched_config_hash(self) -> None:
        spec = BenchmarkSpec(
            benchmark_id="capability-core",
            name="Capability Core",
            kind=BenchmarkKind.CAPABILITY,
            metric="accuracy",
            threshold=0.6,
        )
        gate = EvaluationGate([spec])
        bundle = EvaluationBundle(
            results=(EvaluationResult("capability-core", 0.7),),
            config_hash="0" * 64,
        )

        decision = gate.decide_bundle(bundle)

        self.assertFalse(decision.passed)
        self.assertEqual(decision.blocking_findings[0].status, GateStatus.INVALID)

    def test_gate_blocks_bundle_with_unsupported_schema_version(self) -> None:
        spec = BenchmarkSpec(
            benchmark_id="capability-core",
            name="Capability Core",
            kind=BenchmarkKind.CAPABILITY,
            metric="accuracy",
            threshold=0.6,
        )
        gate = EvaluationGate([spec])
        bundle = EvaluationBundle(
            results=(EvaluationResult("capability-core", 0.7),),
            config_hash=gate.config_hash,
            schema_version="m0-evaluation-gate/v0",
        )

        decision = gate.decide_bundle(bundle)

        self.assertFalse(decision.passed)
        self.assertEqual(decision.blocking_findings[0].status, GateStatus.INVALID)


if __name__ == "__main__":
    unittest.main()
