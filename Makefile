include .common.mk
include .website.mk

define help_top_level_message
For additional help:

make help-programs      # Print help on executable tools, PoCs, etc. (including "contribs").
make help-website       # Print help for the documentation website.
endef

define help_top_level_programs_message
For the consortium-training prototype:

make consortium-demo    # Run the N+1 consortium-training proof-of-concept demo.
endef

print-info::

.PHONY: consortium-demo

consortium-demo::
	@echo "${INFO}Running the consortium-training demo...${_END}"
	uv run python examples/consortium_training_demo.py

# This construct uses the list of .targets.mk files in $(CONTRIB_TARGETS_MKS) and
# includes each one individually to define custom targets for the contributions.
#$(foreach prog_mk,$(CONTRIB_TARGETS_MKS),$(eval -include $(prog_mk)))
include ${CONTRIB_TARGETS_MKS}