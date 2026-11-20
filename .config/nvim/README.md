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
- ImageMagick for Snacks image conversion and Molten plots
- `wl-clipboard` on Wayland or `xclip` on X11 for clipboard image pasting
- Ghostscript for PDF image rendering (optional)
- Tectonic or another LaTeX engine for rendered Markdown math (optional)
- `pynvim` and `jupyter_client` for the system Python, for Molten
  (`python-pynvim` and `python-jupyter-client` on Arch)
- `jupytext` for opening Jupyter notebooks (`uv tool install jupytext`, which
  `bootstrap.sh --packages` runs; it is not in the Arch repositories)
- direnv for per-project environments (optional, recommended)

### Geospatial tools

- ExifTool (`exiftool`) for ordinary image metadata
- GDAL (`gdalinfo`, `ogrinfo` and `gdal_translate`) for raster and vector
  metadata and raster thumbnails
- DuckDB (`duckdb`) for the Neo-tree `E` row preview
- QGIS (`qgis`) for the optional Neo-tree `Q` mapping
- PostgreSQL client tools when using PostGIS through Dadbod

`~/.config/dotfiles/packages.txt` lists all of these by Arch package name.

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

Three AstroCommunity Python packs are imported in `lua/community.lua`:

- `pack.python.base`: `debugpy` debugging, virtual-environment selection with
  venv-selector (`<Leader>lv`, needs `fd`), and pytest integration through
  Neotest
- `pack.python.basedpyright`: BasedPyright completion and type checking
- `pack.python.ruff`: Ruff linting, import sorting, and formatting

The base pack only plugs pytest into Neotest, so `test.neotest` is imported as
well; its keys are under `<Leader>T`.

Global BasedPyright overrides live in `lua/plugins/python.lua`. They are set
through AstroLSP rather than `after/lsp/`, because the pack configures
BasedPyright with `vim.lsp.config()`, which Neovim ranks above `after/lsp/*.lua`
files. Project settings should normally be committed in `pyproject.toml`, which
takes precedence over both; a starter file is provided at
`examples/pyproject.toml`.

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

### Per-project environments with direnv

Fish loads direnv when it is installed. Copy `examples/.envrc` to a project
root and run `direnv allow`: from then on, entering the directory puts the
project's `.venv` first on `PATH` and loads private settings from an untracked
`.env`, and leaving it undoes both. Start Neovim from inside the project and
BasedPyright, which takes the interpreter from `python` on `PATH`, the
debugger, tests, terminal and Molten kernels all use that environment without
selecting it in venv-selector. The example also shows the database variables
that Dadbod reads (`DATABASE_URL` for `:DB`, `DBUI_URL` and `DBUI_NAME` for
`:DBUI`).

## Running code with Molten

Molten runs code against a Jupyter kernel and shows the output, including
plots drawn with image.nvim, under each cell. Quarto's code runner sends `.qmd`
chunks through it.

One-time setup: install `pynvim` and `jupyter_client` for the system Python
(Molten's host is pinned to `/usr/bin/python3` so project environments don't
need them), then run `:UpdateRemotePlugins` and restart Neovim if `:MoltenInit`
is missing. Each project needs `ipykernel`:

```sh
uv add --dev ipykernel
```

With the project environment active, `<Leader>jmp` registers the project's
kernel (asking for a name the first time) and starts Molten with it.

| Key | Action |
| --- | --- |
| `<Leader>jmp` | Start Molten with the active project environment's kernel |
| `<Leader>jmi` | Start Molten, choosing a kernel |
| `<Leader>je` | Run an operator selection (for example `<Leader>jeip`) |
| `<Leader>jl` / `<Leader>jc` | Run the current line / re-run the current cell |
| `<Leader>jr` (visual) | Run the selection |
| `<Leader>jmh` / `<Leader>jmI` / `<Leader>jmR` | Hide output / interrupt / restart the kernel |
| `]j` / `[j` | Next / previous cell |

In Quarto documents (`<LocalLeader>` is `,`):

| Key | Action |
| --- | --- |
| `<LocalLeader>rc` | Run the current chunk |
| `<LocalLeader>ra` / `<LocalLeader>rA` | Run this and all chunks above / every chunk |
| `<LocalLeader>rl` | Run the current line |
| `<LocalLeader>r` (visual) | Run the chunks in the selection |

AstroCommunity's Molten module maps these under `<Leader>m` and `]c`/`[c`;
`lua/plugins/molten.lua` moves them so they don't collide with the Markdown
keys or Vim's diff navigation.

### Jupyter notebooks

Opening an `.ipynb` file shows the notebook as Markdown text (via jupytext);
saving writes it back as a notebook, keeping existing outputs. Python
notebooks get the `quarto` filetype, so they render like `.qmd` documents and
the Quarto runner keys above send cells to Molten. Code cells are fenced
` ```python ` blocks; add a cell by adding a block. See
`lua/plugins/notebooks.lua`.

## Image and geospatial metadata in Neo-tree

### Opening files

Pressing `<CR>` or `l` on an image that `snacks.image` can render opens the
picture in Neovim. In Ghostty this uses the Kitty graphics protocol. Rendered
formats are PNG, JPEG, GIF, BMP, WebP, HEIC, AVIF, ICNS and TIFF, with
lower-case or upper-case extensions (`.jpg` and `.JPG`); the list is set in
`lua/plugins/markdown.lua`.

- TIFF files are first checked with `gdalinfo`. GeoTIFFs and other spatially
  referenced TIFFs open in the metadata view instead, because they are often
  too large or have too high a bit depth to view as pictures. Plain TIFFs are
  displayed.
- Images Snacks cannot render, such as camera RAW files, open in the metadata
  view.
- SVG files open as text for editing.
- On directories, `l` keeps AstroNvim's behaviour: expand a folder, or move to
  its first child when it is already expanded.

Metadata opens in the main editor window, not in the Neo-tree sidebar.

Press `I` when you want metadata instead. The metadata selection is automatic:

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

### Previewing data

The metadata view shows a dataset's structure; `E` shows its contents:

- **Rasters** (GeoTIFF, JPEG 2000, ERDAS Imagine, VRT and the other raster
  formats above) are rendered by `gdal_translate` to a PNG thumbnail of at
  most 1024 pixels, opened as a picture. Single-band and floating-point data
  such as elevation models are stretched to the full brightness range;
  classified rasters keep their colour table; for three or more bands the
  first three are shown as RGB. A NetCDF/HDF container of subdatasets has no
  bands of its own, so it can't be previewed directly.
- **Tables and vector data** show their first 40 rows, read with DuckDB and
  fitted to the window width: CSV, TSV, Parquet (including GeoParquet), JSON
  Lines, GeoPackage, Shapefile, FlatGeobuf, GeoJSON, KML, GML and GPX. Spatial
  formats use DuckDB's `spatial` extension, which DuckDB downloads the first
  time it is needed.

The commands are built in `lua/dataset_preview.lua`.

### Neo-tree mappings

| Key | Action |
| --- | --- |
| `<CR>` / `l` | Open files normally; display images; inspect GeoTIFFs and binary GIS datasets |
| `E` | Preview contents: a thumbnail for rasters, the first rows for tables and vector data |
| `I` | Inspect image or GIS metadata for the selected file |
| `Q` | Open the selected file in QGIS |

Inside a metadata or row-preview buffer:

| Key | Action |
| --- | --- |
| `r` | Refresh |
| `q` | Close the buffer |

If GDAL is unavailable, ordinary images still use ExifTool and the metadata
buffer states that spatial-image detection was skipped.

## Structured data and databases

The configuration includes support for JSON, YAML, TOML, XML, CSV, SQL, and
large files. AstroNvim's built-in large-file check turns off expensive editor
features such as Tree-sitter highlighting for files over 1.5 MB, over
100,000 lines, or with a line over 1,000 characters, which catches minified
GeoJSON that is small on disk but a single huge line.

Dadbod provides PostgreSQL/PostGIS connections and query buffers. Keep database
credentials outside this repository, using environment variables, `.pgpass`,
or another local secret store.

## Quarto and Markdown

Quarto support is enabled for reproducible scientific reports. Markdown and
Quarto buffers are rendered inside Neovim with `render-markdown.nvim`, while
`snacks.image` displays referenced images inline in supported terminals such as
Ghostty. In insert mode the rendered Markdown decorations get out of the way so
the source remains easy to edit.

Clipboard screenshots and images can be pasted with `img-clip.nvim`. They are
saved beneath an `assets/` directory relative to the current document and a
relative Markdown image link is inserted automatically.

### Markdown mappings

| Key | Action |
| --- | --- |
| `<Leader>mh` | Show the image under the cursor in a larger floating preview |
| `<Leader>mp` | Paste a clipboard image into `assets/` and insert its Markdown link |
| `<Leader>mr` | Toggle rendered Markdown for the current buffer |
| `<Leader>ms` | Open render-markdown's side preview |
| `<Leader>mb` | Toggle the browser-based Markdown Preview |

The browser preview commands remain available for Markdown files:

```vim
:MarkdownPreview
:MarkdownPreviewToggle
:MarkdownPreviewStop
```

After installation, verify the image and clipboard integrations with:

```vim
:checkhealth snacks
:checkhealth img-clip
```

A minimal image test is:

```markdown
# Image test

![Example](./assets/example.png)
```

The Quarto plugin registers its Tree-sitter language as Markdown, so `.qmd`
documents receive the same rendered Markdown treatment and inline-image
parsing.

## Colour scheme

Neovim uses Catppuccin to match Ghostty. At startup Neovim asks the terminal for
its background colour, and Catppuccin picks Latte for a light background and
Mocha for a dark one, following Ghostty's light/dark switch. A Neovim that is
already open keeps its flavour until restarted. See `lua/plugins/colorscheme.lua`.

## Important files

```text
lua/community.lua                   Python/data/database community packs
lua/plugins/python.lua              BasedPyright overrides
lua/plugins/molten.lua              Molten, image.nvim for plots, Quarto runner
lua/plugins/neo-tree-geospatial.lua Metadata, previews and QGIS integration
lua/dataset_preview.lua             DuckDB row-preview and GDAL thumbnail commands
lua/plugins/notebooks.lua           Jupyter notebooks through jupytext
lua/plugins/markdown.lua            Inline images, rendered Markdown and image paste
lua/plugins/colorscheme.lua         Catppuccin following the terminal
lua/polish.lua                      Filetype and indentation additions
examples/pyproject.toml             Python project baseline
examples/.envrc                     direnv template for projects
```
