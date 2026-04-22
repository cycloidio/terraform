# Personal Claude Instructions for Lukasz

## Private Rules

- This repo uses plain `go` tooling, not `make test` / `make lint`. Don't reach for the YouDeploy-style Makefile targets here.
- Before editing, check `git branch --show-current` — cycloid patches differ across `cy-v*` maintenance branches, and a fix applied on the wrong branch is wasted work.
- When exposing an internal identifier, the minimum-surface rule matters more than elegance: I'd rather merge one capitalized field than a nicely designed public wrapper.
