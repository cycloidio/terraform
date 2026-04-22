# Claude Code Instructions for Cycloid's Terraform Fork

## Project Overview

This is Cycloid's fork of [hashicorp/terraform](https://github.com/hashicorp/terraform). It is **not** a consumer product — it is a library fork. Downstream Cycloid services (e.g. `youdeploy-http-api`) import packages from this repo to re-use Terraform's parser, graph engine, plan/apply machinery, state types, addresses, etc. without shelling out to the `terraform` binary.

Upstream moved most of Terraform's interesting code under `internal/` so it cannot be imported from outside the module. The purpose of this fork is to **selectively re-expose types, functions, and methods** from `internal/` (and apply small compatibility patches) so downstream code can depend on them directly.

The module path is still `github.com/hashicorp/terraform` on purpose — downstream repos pin this fork with a `replace` directive so upstream import paths keep working.

## Core Rules

- **Minimize drift from upstream.** Every diff against `hashicorp/terraform` is a merge conflict waiting to happen the next time we rebase on a new upstream tag. Don't refactor, rename, or reformat upstream code. Touch only what is strictly needed.
- **Expose, don't rewrite.** The standard pattern is: capitalize an identifier, add a thin public wrapper, or move a declaration out of a private helper — never rewrite the logic behind it.
- **Preserve upstream style.** When editing existing files, match HashiCorp's conventions exactly (naming, comment style, error wrapping with `fmt.Errorf`, tfdiags, etc.). Do **not** apply conventions from other Cycloid repos (no `yderr`, no `slog`, no `make`-based workflows).
- **Keep cycloid changes identifiable.** Commits that expose internals or patch upstream behavior are conventionally titled `cycloid fixes` (see `git log --grep=cycloid`). Follow that pattern unless the user says otherwise.
- **English only**, no emojis, no trailing periods on comments, state the *why* not the *what*.

## Repository Layout

This is the upstream Terraform layout — do not reorganize it.

```
terraform/
├── main.go, commands.go, ...   # CLI entry point (kept buildable but we don't ship it)
├── internal/                   # Upstream's private packages — the main target of this fork
│   ├── addrs/                  # Resource addresses, modules, providers
│   ├── backend/                # State backends
│   ├── command/                # CLI command implementations
│   ├── configs/                # HCL config parsing
│   ├── dag/                    # Directed acyclic graph used by the graph builder
│   ├── lang/                   # Expression evaluation
│   ├── plans/                  # Plan types
│   ├── providers/              # Provider plugin interface
│   ├── states/                 # State representation and storage
│   ├── terraform/              # Core graph engine, contexts, transformers
│   ├── tfdiags/                # Diagnostics
│   └── ...
├── version/                    # Version string
├── scripts/                    # build.sh, gofmtcheck.sh, staticcheck.sh, exhaustive.sh
├── tools/                      # Developer tooling (protobuf-compile etc.)
└── Makefile                    # Minimal — only generate, protobuf, fmtcheck, staticcheck, website
```

There are **multiple long-lived branches** pinned to specific upstream versions (`cy-v1.1.9`, `cy-v1.4.6`, `cy-v5.66.0`, …). Always confirm which branch we're on with `git status` before making changes — cycloid patches on `cy-v1.4.6` may not apply cleanly to `cy-v1.1.9`.

## How to Expose an Internal API

Typical requests sound like *"expose X so we can use it from youdeploy"*. The recipe:

1. **Find the smallest surface that unblocks the caller.** If they only need one field or one method, don't export the whole struct. Overexposing makes future upstream merges noisier.
2. **Prefer capitalization over restructuring.** If a type/function/field is already in a sensible package, just rename `fooBar` → `FooBar` in place. Don't move it.
3. **When the identifier can't be capitalized in place** (e.g. it's a method on an already-exported type, or it collides), add a thin exported wrapper/accessor in the same file rather than refactoring.
4. **Leave surrounding code untouched.** Don't reformat imports, don't tidy neighbouring functions, don't add comments to unrelated code. The diff should be readable in a one-screen review.
5. **Do not change behavior.** If you find a bug while exposing something, either fix it in a separate commit labelled clearly as a behavior change, or leave it alone.
6. **No new abstractions.** Don't introduce interfaces, factories, or option structs on our side. Downstream can build those if it wants them.

## Build, Test & Code Quality

This repo uses plain Go tooling, not a custom Makefile wrapper. Do **not** invent `make test`, `make lint`, `make format-go` etc. — they don't exist here.

```bash
go build ./...                         # compile everything
go test ./...                          # run all tests
go test ./internal/terraform/...       # test a specific subtree
go test -run TestFoo ./internal/plans  # single test
go vet ./...
gofmt -w .                             # or scripts/gofmtcheck.sh to check only

make generate        # go generate ./... (string stringers, mocks, etc.)
make protobuf        # regenerate protobuf stubs (needs protoc installed)
make fmtcheck        # scripts/gofmtcheck.sh
make staticcheck     # scripts/staticcheck.sh
make exhaustive      # scripts/exhaustive.sh
```

Generated files (`*_string.go`, anything under a `gen/` dir, `*.pb.go`) must never be hand-edited — change the source and re-run the relevant generator.

## Code Conventions (upstream HashiCorp)

When writing new code or editing existing code in this repo, follow upstream conventions — **not** the conventions used in other Cycloid repositories:

- **Errors**: use `fmt.Errorf("...: %w", err)` and `errors.Is/As`. Terraform also uses `tfdiags.Diagnostics` for user-facing errors in the core/command layers — respect which style the surrounding file already uses.
- **Logging**: the codebase uses `hashicorp/go-hclog` and the standard `log` package. Do not introduce `slog` here.
- **Context**: not every function takes a `context.Context` — follow the surrounding signature.
- **Comments**: upstream uses godoc-style comments starting with the identifier name (`// FooBar does X.`). Preserve that.
- **Tests**: table-driven with `t.Run(name, func(t *testing.T) { ... })`. Plain `testing` package, occasional `github.com/google/go-cmp/cmp`. No `testify` unless the file already uses it. Fixtures live under `testdata/` directories.

## Working with Upstream

- The upstream repo is `github.com/hashicorp/terraform`. It is **not** configured as a git remote here; `origin` points to `git@github.com-cycloid:cycloidio/terraform.git`. Add upstream only when explicitly asked to pull or compare.
- When the user asks to "port a fix from upstream" or "rebase on vX.Y.Z", surface the plan before executing — rebases of these branches are high-risk and the user should review the strategy first.
- Never force-push shared branches (`main`, `cy-v*`) without explicit confirmation.

## Things NOT to Do

- ❌ Don't change the module path (`github.com/hashicorp/terraform`). Downstream replace-directives depend on it.
- ❌ Don't move files out of `internal/`. Re-exposing does not require relocation, and moving breaks upstream merges.
- ❌ Don't introduce Cycloid-specific packages, helpers, or style guides into this tree.
- ❌ Don't "clean up" upstream code you happen to pass through.
- ❌ Don't add new dependencies unless the change truly requires one — and even then, prefer vendoring/updating an existing one.
- ❌ Don't delete `internal/` code even if it looks unused — downstream or the CLI may still import it.
