# This contribution is an excerpted, as-published reference implementation (see
# README.md); its dependencies (transformers, peft, trl, pandas, ...) are not part
# of the project's own dependency set, so pylint/type-check are not meaningful here.
# This effectively skips the "pylint" and "type-check" targets defined in the
# top-level Makefile.
pylint-default type-check-default:
	@echo "${skip-contrib-target}"
	@true
