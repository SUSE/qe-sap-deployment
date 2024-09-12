
# Flake8 codes:
# E501 line too long (XX > 79 characters)

base_dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

all: static test

static: static-py static-terraform static-ansible

static-py: static-pylint static-flake8

static-terraform: static-terraform-fmt static-terraform-validate

static-ansible: static-ansible-yaml static-ansible-syntax

test: test-ut test-e2e

test-all: test-ut test-ut-fuzzy test-ut-verbose test-ut-dep  test-e2e

beyond: all static-flake8-test static-ansible-kics static-terraform-kics static-ansible-lint test-ut-fuzzy test-ut-verbose test-ut-dep

static-pylint:
	@cd scripts/qesap/ ; tox -e pylint

static-flake8:
	@cd scripts/qesap/ ; tox -e flake8

static-terraform-fmt: static-terraform-fmt-azure static-terraform-fmt-aws static-terraform-fmt-gcp

static-terraform-fmt-azure:
	@cd terraform/azure ; terraform fmt -check -recursive -diff

static-terraform-fmt-aws:
	@cd terraform/aws ; terraform fmt -check -recursive -diff

static-terraform-fmt-gcp:
	@cd terraform/gcp ; terraform fmt -check -recursive -diff

static-terraform-validate: static-terraform-validate-azure static-terraform-validate-aws static-terraform-validate-gcp

static-terraform-validate-azure:
	@cd terraform/azure ; terraform init ; terraform validate

static-terraform-validate-aws:
	@cd terraform/aws ; terraform init ; terraform validate

static-terraform-validate-gcp:
	@cd terraform/gcp ; terraform init ; terraform validate

static-ansible-yaml:
	@tools/ansible_yaml_lint

static-ansible-syntax: export ANSIBLE_ROLES_PATH=tools/dummy_roles
static-ansible-syntax:
	@python3 --version ; python3 tools/ansible_playbook_syntax_check.py

static-ansible-lint:
	@ansible-lint --offline ansible/

test-ut:
	@cd scripts/qesap/ ; tox -e py311

test-ut-fuzzy:
	@cd scripts/qesap/ ; tox -e pytest_hypo

test-ut-verbose:
	@cd scripts/qesap/ ; tox -e pytest_verbose

test-ut-dep:
	@cd scripts/qesap/ ; tox -e pytest_finddep

test-e2e:
	@cd scripts/qesap/test/e2e ; ./test.sh

tox:
	@cd scripts/qesap/ ; tox

static-flake8-test:
	@cd scripts/qesap/ ; tox -e flake8_test

static-ansible-kics:
	@podman run -t -v $(base_dir)/ansible:/path -v $(base_dir):/kics --env DISABLE_CRASH_REPORT=0  checkmarx/kics:v2.0.1 scan -p /path -o "/path/" --config /kics/kics-config.json

static-terraform-kics:
	@podman run -t -v $(base_dir)/terraform:/path -v $(base_dir):/kics --env DISABLE_CRASH_REPORT=0  checkmarx/kics:v2.0.1 scan -p /path -o "/path/" --config /kics/kics-config.json
