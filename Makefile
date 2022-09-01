
# Flake8 codes:
# E265 block comment should start with '# '
# E501 line too long (XX > 79 characters)
# F841 local variable 'xxx' is assigned to but never used

test:
	@find -type f -name \*.sh -exec bash -n {} \;
	@find scripts -type f -name \*.py -exec pylint --disable=line-too-long,missing-class-docstring,missing-function-docstring,missing-module-docstring,too-many-branches,unused-argument,too-many-locals,too-many-arguments,duplicate-code {} +
	@find scripts -type f -name \*.py -exec flake8 --ignore=E265,E501,F841 {} +
	@PYTHONPATH=scripts/qesap pytest-3
