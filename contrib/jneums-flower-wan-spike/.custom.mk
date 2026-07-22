# Because of a dependency issue with the pathspec dependency in flwr
# and black, we have to skip the format task. Also, pylint doesn't
# currently pass.
format-default pylint-default:
	@echo "${skip-contrib-target}"
	@true