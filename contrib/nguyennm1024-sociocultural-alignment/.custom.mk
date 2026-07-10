# TODO: While the process for running the unit tests works locally, it fails
# in the PR process. See issue #146 (https://github.com/The-AI-Alliance/tapestry/issues/146)
# for details.

# unit-tests-prerequisite::
# 	@cd ${SRC_DIR}; \
# 	echo "Building $@ in $$(pwd)."; \
# 	if [ -d .venv ]; \
# 	then echo "${WARN}'.venv' already exists; not running 'uv venv'.${_END}"; \
# 	else \
# 		uv venv; \
# 		echo "running: uv pip install --requirements requirements.txt"; \
# 		uv pip install --requirements requirements.txt; \
# 	fi

# Override the default, even though we run similar commands as are used in
# ../../Makefile, because the unit-tests-default defined there runs in the
# project root directory, whereas we have to run the test commands in this
# directory, because a separate environment is setup here.
# unit-tests-default:
# 	@cd ${SRC_DIR}; \
# 	echo "${INFO}Building $@ in $$(pwd).${_END}"; \
# 	echo "running: which source"; \
# 	which source; \
# 	echo "running: source $$(pwd)/.venv/bin/activate"; \
# 	source $$(pwd)/.venv/bin/activate; \
# 	echo "running: ${PYTEST_RUN_CMD} && ${PYTEST_COV_REPORT_CMD}"; \
# 	${PYTEST_RUN_CMD} && ${PYTEST_COV_REPORT_CMD}

# This definition effectively skips the, "ruff", "pylint", "type-check",
# and "unit-tests" targets defined in the top-level Makefile.
ruff-default pylint-default type-check-default unit-tests-default:
	@echo "${skip-contrib-target}"
	@true
