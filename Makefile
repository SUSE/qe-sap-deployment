
# Flake8 codes:
# E501 line too long (XX > 79 characters)

base_dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

all: static test

static: static-bash static-py static-ansible

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
	@tools/ansible_yaml_lint

static-ansible-syntax: export ANSIBLE_ROLES_PATH=tools/dummy_roles
static-ansible-syntax:
	@find ansible/playbooks/ -type f -iname "*.yaml" -maxdepth 1  -exec ansible-playbook -l all -i tools/inventory.yaml --syntax-check  {} +

static-ansible-lint:
	@ansible-lint ansible/

static-ansible-kics:
	@podman run -t -v $(base_dir)/ansible:/path -v $(base_dir):/kics --env DISABLE_CRASH_REPORT=0  checkmarx/kics:v1.6.14 scan -p /path -o "/path/" --config /kics/kics-config.json

static-terraform-kics:
	@podman run -t -v $(base_dir)/terraform:/path -v $(base_dir):/kics --env DISABLE_CRASH_REPORT=0  checkmarx/kics:v1.6.14 scan -p /path -o "/path/" --config /kics/kics-config.json

static-ansible: static-ansible-yaml static-ansible-lint static-ansible-syntax

test:
	@PYTHONPATH=scripts/qesap pytest
