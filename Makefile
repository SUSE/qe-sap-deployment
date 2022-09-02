
# Flake8 codes:
# E501 line too long (XX > 79 characters)

all: static test

static: static-bash static-py

static-bash:
	@find -type f -name \*.sh -exec bash -n {} \;
	@find -type f -name \*.sh -exec shellcheck {} -o all -s bash -S info \;

static-py:
	@find scripts -type f -name \*.py -exec pylint --rcfile=scripts/qesap/pylint.rc qesap.py {} +
	@find scripts -type f -name \*.py -exec pylint --disable=line-too-long,missing-class-docstring,missing-function-docstring,missing-module-docstring,too-many-branches,unused-argument,too-many-locals,too-many-arguments,duplicate-code {} +
	@find scripts -type f -name \*.py -exec flake8 --ignore=E501 {} +

test:
	@PYTHONPATH=scripts/qesap pytest-3
