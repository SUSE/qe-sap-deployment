# How to contribute

Fork the repository and make some changes.
Once you're done with your changes send a pull request. You have to agree to
the license. Thanks!

## How to get started

It can be beneficial to learn how deployment is executed. Check the main README.

If you are looking for a task to start with, check out the Issue page on Github.

## How to get this repository working

Upon having all tools referred in the main README, it's also necessary to install some additional Python dependencies that are listed in `requirements-dev.txt`.

### Relevant documentation

* All cloud provider folder in Terraform has additional documentation.

### Reporting an issue

We use Github issue tracking. In case you found some
problem with the tests, please do not hesitate report a new issue.

## Coding style

The project is composed by files in many different code languages: Terraform, Ansible (YAML) and Python. Some rules are in common:

* Use a "SPDX-License-Identifier" to declare the used license. Do not copy
  verbatim license texts into new files
* Prefer to not update the copyright years in file headers as this is not
  required. In new files the year can be skipped completely, e.g. just
  "Copyright SUSE LLC".
* The test code should use simple statements, not overly hacky
  approaches, to encourage contributions by newcomers and test writers which
  are not programmers or experts
* [DRY](https://en.wikipedia.org/wiki/Don't_repeat_yourself)
* Avoid "dead code": Don't add disabled code as nobody but you will understand
  why this is not active. Better leave it out and keep in your local git
  repository, either in `git stash` or a temporary "WIP"-commit.
* Details in commit messages: The commit message should have enough details,
  e.g. what issue is fixed, why this needs to change, to which versions of which
  product it applies, link to a bug or a feature entry, the choices you made,
  etc.
  Also see [this](https://commit.style/) or [this](http://chris.beams.io/posts/git-commit/) as a helpful guide how to write good commit messages.
  And make code reviewers [fall in love with you](https://mtlynch.io/code-review-love/) :)
  Keep in mind that the text in the Github pull request description is only
  visible on Github, not in the git log which can be considered permanent
  information storage.
* Add comments to the source code if the code is not self-explanatory:
  Comments in the source code should describe the choices made, to answer the
  question "why is the code like this". The git commit message should describe
  "why did we change it".

## Preparing a new Pull Request

* All code needs to be checked locally. As the repository contains different kinds of code (Terraform, Ansible, Python, Documentation, bash scripts), any PR need to be prepared in different way, accordingly to its content:
  * Documentation: some of the Markdown files are tested for Markdown syntax and spelling.
  * Python code: it is mostly important for the glue script code in `scripts/qesap`. The code is statically tested with pylint and flake8. These tests can be executed manually with `make static-py` or with `tox -e pylint`. Some unit testing are also associated with the qesap.py script. They can be executed with `tox` or using `make test`.
  * Ansible code: code can be statically tested using `make static-ansible`.

* Every pull request is tested by our CI system for different purposes:

Also see the [DoD/DoR][1] as a helpful (but not mandatory) guideline for new contributions.

[1]: https://progress.opensuse.org/projects/openqatests/wiki/Wiki#Definition-of-DONEREADY
