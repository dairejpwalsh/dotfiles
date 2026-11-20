#!/usr/bin/env bash
# Installs what the Neovim checks need on an Ubuntu GitHub runner and points
# Neovim at this checkout. Used by ci.yml and update-plugins.yml.
set -euo pipefail

: "${DUCKDB_VERSION:?set DUCKDB_VERSION in the workflow}"

bin="$RUNNER_TEMP/bin"
mkdir -p "$bin"

# Use the checkout as the Neovim configuration; keep plugin data out of it.
{
  echo "XDG_CONFIG_HOME=$GITHUB_WORKSPACE/.config"
  for dir in data state cache; do echo "XDG_${dir^^}_HOME=$RUNNER_TEMP/xdg/$dir"; done
} >>"$GITHUB_ENV"

curl -fsSL https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz |
  tar -xz -C "$RUNNER_TEMP"
echo "$RUNNER_TEMP/nvim-linux-x86_64/bin" >>"$GITHUB_PATH"

curl -fsSL -o "$RUNNER_TEMP/duckdb.zip" \
  "https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/duckdb_cli-linux-amd64.zip"
unzip -q "$RUNNER_TEMP/duckdb.zip" -d "$bin"
echo "$bin" >>"$GITHUB_PATH"

npm install --global --silent tree-sitter-cli
pipx install jupytext # notebooks (jupytext.nvim)
echo "$HOME/.local/bin" >>"$GITHUB_PATH"

sudo apt-get update -qq
# python3-pynvim/jupyter-client: Molten's Python host. fd-find: venv-selector
# is only enabled when fd is installed. gdal-bin: raster thumbnails.
sudo apt-get install -y -qq python3-pynvim python3-jupyter-client fd-find gdal-bin
