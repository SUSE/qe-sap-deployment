
# Flake8 codes:
# E501 line too long (XX > 79 characters)

all: static test

static: static-bash static-py

static-bash:
	@find -type f -name \*.sh -exec bash -n {} \;
	@find -type f -name \*.sh -exec shellcheck {} -o all -s bash -S info \;

static-pylint:
	@find scripts -type f -name \*.py -exec pylint --rcfile=scripts/qesap/pylint.rc qesap.py {} +

static-flake8:
	@find scripts -type f -name \*.py -exec flake8 --ignore=E501 {} +

static-py: static-pylint static-flake8

test:
	@PYTHONPATH=scripts/qesap pytest
