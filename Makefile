
# Flake8 codes:
# E501 line too long (XX > 79 characters)

all: static test

static: static-bash static-py

static-bash:
	bash -n build.sh
	shellcheck build.sh -o all -s bash -S info
	bash -n destroy.sh
	shellcheck destroy.sh -o all -s bash -S info

static-pylint:
	@find scripts -type f -not -path "scripts/qesap/.tox/*" -not -path "scripts/qesap/.venv/*" -name \*.py -exec pylint --rcfile=scripts/qesap/pylint.rc qesap.py {} +

static-flake8:
	@find scripts -type f -not -path "scripts/qesap/.tox/*" -not -path "scripts/qesap/.venv/*" -name \*.py -exec flake8 --ignore=E501 {} +

static-py: static-pylint static-flake8

test:
	@PYTHONPATH=scripts/qesap pytest
