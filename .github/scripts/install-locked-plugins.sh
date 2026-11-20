#!/usr/bin/env bash
# Installs Neovim's plugins at the versions in lazy-lock.json. On first start
# lazy.nvim installs missing plugins at the newest versions their specs allow
# and rewrites the lockfile, so put the committed lockfile back and restore it.
set -euo pipefail

nvim --version | sed -n 1p
timeout 900 nvim --headless +qa
git checkout -- .config/nvim/lazy-lock.json
timeout 900 nvim --headless "+Lazy! restore" +qa
