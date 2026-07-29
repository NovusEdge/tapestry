# Formal specification (Quint) targets.
#
# Install the pinned Quint toolchain and run the spec checks for a spec
# directory. SPEC_DIR defaults to the canonical top-level `spec/`; override it
# to validate a spec staged elsewhere, e.g. while the pilot lives in contrib:
#
#   make formal-spec-verify SPEC_DIR=contrib/luzanikita-formal-spec
#
# When SPEC_DIR has no `package.json` (e.g. `spec/` is still empty), both
# targets no-op so CI stays green until specs are added or promoted.

SPEC_DIR ?= spec

define help-formal-spec-message

${HIGHLIGHT}Formal specification (Quint) targets:${_END}

${CODE}make formal-spec-install${_END}  # Install the pinned Quint toolchain in ${CODE}$(SPEC_DIR)${_END} (skips if empty).
${CODE}make formal-spec-verify${_END}   # Typecheck + run invariants + tests in ${CODE}$(SPEC_DIR)${_END} (skips if empty).
${CODE}${_END}                          # Override the directory with ${CODE}SPEC_DIR=<dir>${_END}.
endef

.PHONY: formal-spec-install formal-spec-verify

formal-spec-install::
	@if [ -f "$(SPEC_DIR)/package.json" ]; then \
		echo "${INFO_LABEL}Installing the Quint toolchain in ${CODE}$(SPEC_DIR)${_END}"; \
		cd $(SPEC_DIR) && npm ci; \
	else \
		echo "${WARNING_LABEL}No formal specs in ${CODE}$(SPEC_DIR)${_END} (no package.json) — skipping ${CODE}formal-spec-install${_END}."; \
	fi

formal-spec-verify::
	@if [ -f "$(SPEC_DIR)/package.json" ]; then \
		echo "${INFO_LABEL}Verifying formal specs in ${CODE}$(SPEC_DIR)${_END}"; \
		cd $(SPEC_DIR) && npm run spec:check; \
	else \
		echo "${WARNING_LABEL}No formal specs in ${CODE}$(SPEC_DIR)${_END} (no package.json) — skipping ${CODE}formal-spec-verify${_END}."; \
	fi
