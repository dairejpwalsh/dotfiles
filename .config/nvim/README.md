# AstroNvim Python and geospatial configuration

A focused AstroNvim v6 configuration for Python development, geospatial data,
PostGIS, structured data files, and reproducible Quarto reports.

## Requirements

### AstroNvim

- Neovim 0.11 or newer, using a stable release
- Git
- A C compiler
- A Nerd Font
- Tree-sitter CLI, or allow Mason to install it
- `ripgrep` and `fd`/`fdfind` are strongly recommended
- Python 3.11 or newer
- Node.js for language servers and Markdown Preview

### Geospatial tools

- ExifTool (`exiftool`) for ordinary image metadata
- GDAL (`gdalinfo` and `ogrinfo`) for raster and vector metadata
- QGIS (`qgis`) for the optional Neo-tree `Q` mapping
- PostgreSQL client tools when using PostGIS through Dadbod

## Installation

Back up an existing Neovim setup:

```sh
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

Extract or clone this configuration to `~/.config/nvim`, then start Neovim:

```sh
nvim
```

Lazy.nvim, AstroNvim, AstroCommunity plugins, language servers, formatters,
linters, debug adapters, and parsers are installed on first launch. Run
`:AstroUpdate` after the initial installation and `:checkhealth` to verify the
environment.

To test without replacing an existing configuration, place the directory at
`~/.config/astronvim_geo` and run:

```sh
NVIM_APPNAME=astronvim_geo nvim
```

## Python tooling

The AstroCommunity `python-ruff` pack provides:

- BasedPyright completion and type checking
- Ruff linting, import sorting, and formatting
- Python virtual-environment selection
- `debugpy` debugging
- pytest integration through Neotest

Global BasedPyright defaults live in `after/lsp/basedpyright.lua`. Project
settings should normally be committed in `pyproject.toml`; a starter file is
provided at `examples/pyproject.toml`.

A recommended project layout is:

```text
project/
├── .venv/
├── pyproject.toml
├── uv.lock
├── src/
├── tests/
├── data/
└── outputs/
```

When using `uv`, create the project environment with:

```sh
uv sync
```

For an existing Conda or Mamba project, keep using that environment. The LSP,
debugger, tests, and terminal should all point to the same interpreter.

## Image and geospatial metadata in Neo-tree

### Opening files

Pressing `<CR>` or `l` on any recognised image opens a metadata buffer instead
of loading the binary file into Neovim.

The metadata selection is automatic:

1. `gdalinfo -json` checks whether the image has spatial referencing such as a
   coordinate system, geotransform, ground control points, RPC metadata, or
   geolocation metadata.
2. Spatially referenced images are displayed with `gdalinfo`.
3. Ordinary images are displayed with `exiftool -G -a -s`.

This works for GeoTIFF and also for georeferenced JPEG, PNG, JPEG 2000, and
other formats supported by GDAL. Detection and metadata commands are
asynchronous, so Neovim remains responsive.

Opening common binary raster datasets uses `gdalinfo`. Opening common binary
vector datasets such as Shapefiles, GeoPackages, FlatGeobuf, and GeoParquet
uses `ogrinfo -al -so`. Text formats such as GeoJSON, KML, GML, and VRT retain
normal editing behavior.

### Neo-tree mappings

| Key | Action |
| --- | --- |
| `<CR>` / `l` | Open normally, or inspect an image/binary GIS dataset |
| `I` | Inspect metadata for the selected file |
| `Q` | Open the selected file in QGIS |

Inside a metadata buffer:

| Key | Action |
| --- | --- |
| `r` | Refresh metadata |
| `q` | Close the buffer |

If GDAL is unavailable, ordinary images still use ExifTool and the metadata
buffer states that spatial-image detection was skipped.

## Structured data and databases

The configuration includes support for JSON, YAML, TOML, XML, CSV, SQL, and
large files. The Bigfile integration disables expensive editor features for
very large datasets.

Dadbod provides PostgreSQL/PostGIS connections and query buffers. Keep database
credentials outside this repository, using environment variables, `.pgpass`,
or another local secret store.

## Quarto and Markdown

Quarto support is enabled for reproducible scientific reports. Markdown Preview
is also available:

```vim
:MarkdownPreview
:MarkdownPreviewToggle
:MarkdownPreviewStop
```

## Important files

```text
after/lsp/basedpyright.lua          BasedPyright defaults
lua/community.lua                   Python/data/database community packs
lua/plugins/neo-tree-geospatial.lua Metadata and QGIS integration
lua/plugins/markdown-preview.lua    Browser Markdown preview
lua/polish.lua                      Filetype and indentation additions
examples/pyproject.toml             Python project baseline
```
