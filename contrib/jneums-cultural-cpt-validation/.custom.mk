
override define help_targets_message
For the EXP-001 cultural-CPT validation harness (contrib):

make cultural-cpt-all          # Make all the following targets.

make cultural-cpt-validation   # Run the arms experiment, single seed (smoke mode).
make cultural-cpt-aggregation  # Run the FedAvg aggregation-survival experiment.
make cultural-cpt-stats        # Run the multi-seed go/no-go decision (smoke mode).
make cultural-cpt-tests        # Run the cultural-CPT harness tests.

make cultural-cpt-fetch-seed   # Fetch the real EXP-001 demonstration seed corpus (needs network).
make cultural-cpt-validate-corpus
                               # Validate the corpus against the EXP-001 controls.

endef

# This definition effectively skips the "pylint" and "type-check" targets defined
# in the top-level Makefile.
pylint-default type-check-default:
	@echo "${WARN} ${skip-contrib-target}${_END}"
	@true
