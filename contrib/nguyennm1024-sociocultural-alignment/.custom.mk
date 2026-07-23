# Skip linters - this contrib's code style differs from top-level
format-default ruff-default pylint-default type-check-default:
	@echo "${skip-contrib-target}"
	@true
