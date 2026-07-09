unit-tests-prerequisite::
	@cd ${SRC_DIR}; \
	echo "Building $@ in $$(pwd)."; \
	if [ -d .venv ]; \
	then echo "${WARN}'.venv' already exists; not running 'uv venv'.${_END}"; \
	else \
		uv venv; \
		echo "running: uv pip install --requirements requirements.txt"; \
		uv pip install --requirements requirements.txt; \
	fi

# Override the default, even though we run similar commands as are used in
# ../../Makefile, because the unit-tests-default defined there runs in the
# project root directory, whereas we have to run the test commands in this
# directory, because a separate environment is setup here.
unit-tests-default:
	@cd ${SRC_DIR}; \
	echo "${INFO}Building $@ in $$(pwd).${_END}"; \
	echo "running: source $$(pwd)/.venv/bin/activate"; \
	source $$(pwd)/.venv/bin/activate; \
	echo "running: ${PYTEST_RUN_CMD} && ${PYTEST_COV_REPORT_CMD}"; \
	${PYTEST_RUN_CMD} && ${PYTEST_COV_REPORT_CMD}

# This definition effectively skips the, "ruff", "pylint" and "type-check"
# targets defined in the top-level Makefile.
ruff-default pylint-default type-check-default:
	@echo "${WARN} ${skip-contrib-target}${_END}"
	@true
