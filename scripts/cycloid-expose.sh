#!/usr/bin/env bash
#
# cycloid-expose.sh
#
# Move every internal/<pkg> directory to <pkg> at the repo root and rewrite
# references that previously joined hashicorp/terraform with "/internal/"
# and <pkg> so they now join hashicorp/terraform directly with <pkg>. This
# makes packages that upstream hides under internal/ importable from
# downstream Cycloid Go modules (which pin this fork via a replace directive).
#
# Rewrite scope: *.go, *.proto, *.mod, *.sh, *.md (Go imports, module paths,
# proto go_package options, ldflags in shell scripts, godoc URLs in docs).
#
# The comment above avoids spelling out the literal "hashicorp/terraform" +
# "/internal/" prefix back-to-back, so re-running the rewrite on this script
# does not mangle its own documentation.
#
# Intended to be run exactly once per upstream bump, on a freshly-created
# cy-v<upstream-tag> branch. See .claude/CLAUDE.md for the full workflow.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# ---- sanity checks -----------------------------------------------------------

if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
	echo "error: tracked files have uncommitted changes; commit or stash before running" >&2
	exit 1
fi

if [ ! -d internal ]; then
	echo "error: no internal/ directory at repo root; nothing to move" >&2
	exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD)"
case "$branch" in
	cy-v*) ;;
	*)
		echo "error: refusing to run on branch '$branch' (expected cy-v*)" >&2
		echo "hint:  git checkout -b cy-v<upstream-tag> <upstream-tag>" >&2
		exit 1
		;;
esac

for d in internal/*/; do
	name="$(basename "$d")"
	if [ -e "$name" ]; then
		echo "error: target '$name' already exists at repo root; cannot move internal/$name" >&2
		exit 1
	fi
done

# ---- 1. .gitignore: unblock tracking of a top-level terraform/ directory -----

if grep -qxF '/terraform' .gitignore; then
	awk '!/^\/terraform$/' .gitignore > .gitignore.tmp && mv .gitignore.tmp .gitignore
	echo "removed '/terraform' from .gitignore"
fi

# ---- 2. git mv internal/<D> <D> for every direct subdir of internal/ --------
#
# Capture the set of tracked-but-ignored files under internal/ first. These
# are files upstream keeps in git despite matching a .gitignore pattern
# (e.g. *.exe testdata). `git mv` silently drops them from the index when
# the destination also matches the ignore rule, so we re-force-add them
# at their new locations after the moves.

tracked_ignored_pre=()
while IFS= read -r f; do
	[ -n "$f" ] && tracked_ignored_pre+=("$f")
done < <(git ls-files -ci --exclude-standard -- 'internal/*' 2>/dev/null)

moved_names=()
for d in internal/*/; do
	name="$(basename "$d")"
	git mv "internal/$name" "$name"
	moved_names+=("$name")
done

# Re-add any tracked-but-ignored file that survived on disk but fell out of
# the index at its new path.
for f in "${tracked_ignored_pre[@]}"; do
	new="${f#internal/}"
	[ -f "$new" ] && git add -f -- "$new"
done

# Build a '|'-separated regex alternation of moved directory names, used by
# Step 6 to rewrite bare filesystem references like "internal/command/..."
# in CI workflows without touching unrelated occurrences of the word.
OLD_IFS=$IFS
IFS='|'
MOVED_PATTERN="${moved_names[*]}"
IFS=$OLD_IFS

# internal/ should now be empty. If it isn't (stray files upstream forgot to
# gitignore), leave it untouched so the operator can inspect.
if [ -z "$(ls -A internal 2>/dev/null)" ]; then
	rmdir internal
fi

# ---- 3. rewrite import / module / go_package paths --------------------------

# perl -i is portable across macOS (BSD) and Linux (GNU) without needing the
# platform-specific `sed -i ''` dance.

find . \
	-path ./.git -prune -o \
	-path ./vendor -prune -o \
	-path ./node_modules -prune -o \
	-path ./scripts/cycloid-expose.sh -prune -o \
	\( -name '*.go' -o -name '*.proto' -o -name '*.mod' -o -name '*.sh' -o -name '*.md' \) \
	-type f -print0 \
	| xargs -0 perl -i -pe 's{github\.com/hashicorp/terraform/internal/}{github.com/hashicorp/terraform/}g'

# ---- 4. rewrite filesystem replace paths in the root go.mod -----------------
#
# Nested modules under the old internal/backend/remote-state/* live at their
# new paths now, so the root go.mod's replace targets need to track them.
# Narrow pattern: only `=> ./internal/...` arrows, to avoid touching anything
# that happens to contain "./internal/" elsewhere.

perl -i -pe 's{=> \./internal/}{=> ./}g' go.mod

# ---- 5. fix upward-traversal replace targets in nested go.mod files ---------
#
# Nested modules (e.g. backend/remote-state/s3/go.mod, legacy/go.mod) pin the
# root module with a relative path like "../../../.." to reach the repo root.
# Each one just moved one directory shallower, so drop exactly one leading
# "../" from that specific replace target. Only the `=> github.com/hashicorp/
# terraform` replace line is rewritten; anything else in these files is left
# alone.

find . \
	-path ./.git -prune -o \
	-path ./vendor -prune -o \
	-name go.mod -type f -print0 \
	| while IFS= read -r -d '' modfile; do
		# skip the root module
		[ "$modfile" = "./go.mod" ] && continue
		perl -i -pe 's{^(replace github\.com/hashicorp/terraform => )\.\./}{$1}' "$modfile"
	done

# ---- 6. rewrite filesystem 'internal/' paths in CI workflows and scripts ----
#
# Shell commands inside GitHub Actions workflows and our own shell scripts
# reference './internal/<pkg>' or bare 'internal/<pkg>' as relative paths.
# Those paths no longer exist, so CI jobs and helper scripts would break.
# Two sub-rewrites are applied:
#
#   (a) './internal/'          -> './'         -- relative-prefix form
#   (b) '<sep>internal/<M>/'   -> '<sep><M>/'  -- bare form, where <M> is a
#       directory we just moved. <sep> is start-of-line or any non-alnum,
#       non-slash, non-underscore char, so unrelated tokens like
#       'company-internal/foo' are left alone.

if [ -n "$MOVED_PATTERN" ]; then
	find . \
		-path ./.git -prune -o \
		-path ./vendor -prune -o \
		-path ./node_modules -prune -o \
		-path ./scripts/cycloid-expose.sh -prune -o \
		\( -name '*.yml' -o -name '*.yaml' -o -name '*.sh' \) \
		-type f -print0 \
		| xargs -0 perl -i -pe "
			s{\\./internal/}{./}g;
			s{(^|[^A-Za-z0-9/_])internal/($MOVED_PATTERN)(/|\$|\\s)}{\${1}\${2}\${3}}g;
		"
fi

# ---- 7. heal symlinks whose target escaped internal/ via ../.. --------------
#
# Symlinks like internal/tfplugin6/tfplugin6.proto -> ../../docs/... carried
# two '../' levels because they lived two directories deep. After the move
# they live one level deep, so the same target overshoots the repo root.
# For any symlink that no longer resolves, try dropping one leading '../'
# from the target and apply the fix if it now resolves.

find . -path ./.git -prune -o -type l -print 2>/dev/null | while IFS= read -r link; do
	target="$(readlink -- "$link")"
	case "$target" in
		/*) continue ;;                       # absolute target, not affected
		../*) ;;
		*) continue ;;                        # sibling/relative targets are fine
	esac
	[ -e "$link" ] && continue                # already resolves, leave alone
	new_target="${target#../}"
	link_dir="$(dirname -- "$link")"
	if [ -e "$link_dir/$new_target" ]; then
		rm -- "$link"
		ln -s -- "$new_target" "$link"
		git add -- "$link"
	fi
done

# ---- 8. drop stale 'internal/' prefixes from copywrite ignore globs ----------
#
# The root .copywrite.hcl's header_ignore list used to say
#   "internal/tfplugin*/**"
# to delegate those directories to their own copywrite configs. After the
# move the directories live at tfplugin*/, so strip the 'internal/' prefix
# inside quoted strings. Narrow rewrite: only touches strings that open
# with "internal/, so unrelated text is left alone.

find . -path ./.git -prune -o -name '.copywrite.hcl' -type f -print0 \
	| xargs -0 perl -i -pe 's{"internal/}{"}g'

# ---- done --------------------------------------------------------------------

cat <<'EOF'

Move + rewrite complete. Suggested next steps:

  go build ./...         # sanity-build the CLI and all libraries
  go vet ./...
  git status             # review the diff (expect ~thousands of renames)
  git add -A
  git commit -m "cycloid fixes"

After the branch is pushed, tag the result so downstream can pin it:

  git tag v<upstream-tag>-cy
  git tag v<upstream-tag>-cy.x
  git push origin v<upstream-tag>-cy v<upstream-tag>-cy.x

EOF
