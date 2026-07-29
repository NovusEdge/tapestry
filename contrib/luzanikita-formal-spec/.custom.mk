# This contribution is a Quint formal specification (see README.md) — it contains
# no Python, so the top-level Python quality gates (format, ruff, pylint,
# type-check, unit-tests) do not apply. Validation is done with Quint instead:
# `npm run spec:check` locally and the `.github/workflows/spec.yml` CI gate.
#
# Skip all Python quality targets so `make before-pr` passes for this contrib.
format-default ruff-default pylint-default type-check-default unit-tests-default:
	@echo "${skip-contrib-target}"
	@true
