
# Contributing to Sunforge

Thanks for your interest in contributing! Sunforge is an early-stage 2D game engine, and contributions are welcome, but please read through this guide before opening a pull request.

## Before You Start

All planned work is tracked as GitHub issues, organized by tier label (`tier-0-editor` through `tier-10-scripting`, plus `post-v1` for deferred polish).

1. Browse the [issue tracker](https://github.com/WillBallentine/Sunforge/issues) for something that interests you.
2. **Comment on the issue and ask to be assigned before starting work.** This avoids multiple people working on the same thing and gives a chance to discuss approach/scope before you invest time. (It helps if you also give a short summary of your approach and plan)
3. Wait until the issue is assigned to you before opening a PR for it.

If you have an idea that isn't already tracked, open a new issue describing it first rather than going straight to a PR.

## Branching

Before starting work, sync your fork's `main` with `upstream`:

```sh
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

Then create a branch off `main` using a short, descriptive name prefixed with the type of change, e.g.:

- `feat-<short-description>` for new features/enhancements
- `bug-<short-description>` for bug fixes

## Pull Requests

- Push your branch to your fork (`git push origin <branch-name>`) and open a pull request from there into `WillBallentine/Sunforge:main`.
- Keep PRs focused on the issue they address, and reference that issue in the PR description.
- **All PRs must be reviewed and approved before being merged into `main`.** Do not merge your own PRs.
- Make sure the project builds (`build.bat`) before requesting review.

## A Note on AI-Generated Code

Generic AI-generated code: submitting output from a chatbot or code-generation tool with little to no review or understanding **will not be accepted at this time**. If you use AI tools as part of your workflow, you're expected to understand, test, and take ownership of everything you submit. PRs that read as unreviewed AI output will be closed.

## Code Style

Match the conventions already used in the codebase (naming, file organization, package structure under `engine/`). When in doubt, follow the patterns in the package you're touching.

## License

By contributing, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
