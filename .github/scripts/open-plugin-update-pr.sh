#!/usr/bin/env bash
# Commits the updated lazy-lock.json to a fixed branch and opens a pull request
# for it, or refreshes the one already open. Used by update-plugins.yml after
# the smoke test passed. With DRY_RUN=true it only prints what it would do.
set -euo pipefail

branch=automation/update-neovim-plugins
lockfile=.config/nvim/lazy-lock.json

# One line per plugin whose locked commit changed or that is new.
changes=$(git diff -U0 -- "$lockfile" | sed -nE 's/^\+  "([^"]+)": .*"commit": "([0-9a-f]{12}).*/- `\1` → `\2`/p')
body=$(
  cat <<EOF
Plugins updated with \`:Lazy update\`. The Neovim smoke test passed with these
versions in the run that opened this pull request.

${changes}

Pull requests opened by GitHub Actions don't trigger the CI workflow
themselves; run it from the Actions tab if you want the full set of checks.
EOF
)

if [[ ${DRY_RUN:-false} == true ]]; then
  echo "Dry run: would push $branch and open or refresh a pull request with:"
  echo "$body"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git switch --quiet -C "$branch"
git commit --quiet -m "Update Neovim plugins" -- "$lockfile"
git push --quiet --force origin "$branch"

open=$(gh pr list --head "$branch" --state open --json number --jq '.[0].number // empty')
if [[ -n $open ]]; then
  gh pr edit "$open" --body "$body"
  echo "Refreshed pull request #$open"
else
  gh pr create --head "$branch" --title "Update Neovim plugins" --body "$body"
fi
