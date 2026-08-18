# Skip linters - this contrib's code style differs from top-level
ruff-default pylint-default type-check-default:
	@echo "${skip-default-target-message}"
	@true
