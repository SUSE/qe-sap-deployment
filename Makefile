
# Flake8 codes:
# E501 line too long (XX > 79 characters)

all: static test

static: static-bash static-py

static-py: static-pylint static-flake8

static-bash:
	bash -n build.sh
	shellcheck build.sh -o all -s bash -S info
	bash -n destroy.sh
	shellcheck destroy.sh -o all -s bash -S info

static-pylint:
	@find scripts -type f -not -path "scripts/qesap/.tox/*" -not -path "scripts/qesap/.venv/*" -name \*.py -exec pylint --rcfile=scripts/qesap/pylint.rc qesap.py {} +

static-flake8:
	@find scripts -type f -not -path "scripts/qesap/.tox/*" -not -path "scripts/qesap/.venv/*" -name \*.py -exec flake8 --ignore=E501 {} +

static-ansible-yaml:
	@find ansible -type f -iname "*.yaml" -or -iname "*.yaml" -exec yamllint {} +

static-ansible-syntax:
	@find ansible/playbooks -type f -iname "*.yaml" -maxdepth 1  -exec ansible-playbook -l all -vvvv -i terraform/azure/inventory.yaml --syntax-check  {} +

static-ansible-lint:
	@ansible-lint ansible/

static-ansible: static-ansible-yaml static-ansible-lint static-ansible-syntax

test:
	@PYTHONPATH=scripts/qesap pytest
