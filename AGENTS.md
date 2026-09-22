## General behavior

- Language Standard: Use Plain English by default for all pull requests, commit messages, etc.
- Technical Documentation: Use Simplified Technical English exclusively when authoring technical documentation, code comments, or architecture specs intended for technical audiences.

## Contributing to this project

- Entry Point: You SHOULD read `README.md`. It contains usage information for the project. Also read `terraform/aws/README.md`, `terraform/azure/README.md`, and `./terraform/gcp/README.md` for how Terraform is used in the project, and read `docs/playbooks/README.md` for documentation on the ansible playbooks included with the project.
- Contribution Mandate: You MUST follow `CONTRIBUTING.md` to contribute properly.
- LLM Attribution Standard:
  - Any work produced with LLM tool assistance MUST include an `Assisted-by:` trailer in the commit message metadata (e.g., `Assisted-by: Qwen3-4B`). Include one line per model involved.
  - Agents MUST NOT add `Signed-off-by:` or `Co-authored-by:` trailers, these are strictly reserved for human contributors.
  - A general `Assisted-by: AI` is also acceptable.
- Never `git commit`. Feel free to suggest commit messages, but instruct your user to perform the commit themselves.
