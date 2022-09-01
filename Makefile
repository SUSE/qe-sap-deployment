
# Flake8 codes:
# E265 block comment should start with '# '
# E501 line too long (XX > 79 characters)
# E741 ambiguous variable name
# F841 local variable 'xxx' is assigned to but never used

test:
	@find -type f -name \*.sh -exec bash -n {} \;
	@find scripts -type f -name \*.py -exec pylint --disable=import-error,import-outside-toplevel,invalid-name,line-too-long,missing-class-docstring,missing-final-newline,missing-function-docstring,missing-module-docstring,redefined-outer-name,too-many-branches,too-many-return-statements,unspecified-encoding,unused-argument,unused-import,unused-variable,wrong-import-order,too-many-locals,too-many-arguments {} \;
	@find scripts -type f -name \*.py -exec flake8 --ignore=E203,E265,E501,E741,F401,F841,W292 {} \;
