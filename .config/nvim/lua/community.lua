-- AstroCommunity modules are imported before the local plugins directory so
-- local plugin specifications can override their defaults when necessary.
---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  -- Catppuccin, matching Ghostty (configured in lua/plugins/colorscheme.lua).
  { import = "astrocommunity.colorscheme.catppuccin" },

  -- Python: debugpy, virtual environments and pytest (base), BasedPyright,
  -- and Ruff. Local overrides live in lua/plugins/python.lua.
  { import = "astrocommunity.pack.python.base" },
  { import = "astrocommunity.pack.python.basedpyright" },
  { import = "astrocommunity.pack.python.ruff" },

  -- Project and geospatial data formats.
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.xml" },

  -- SQL/PostGIS editing and database access.
  { import = "astrocommunity.pack.sql" },
  { import = "astrocommunity.pack.full-dadbod" },

  -- Structured data inspection. Large files are handled by AstroCore's
  -- built-in large_buf check, which also catches very long lines such as
  -- minified GeoJSON.
  { import = "astrocommunity.programming-language-support.csv-vim" },
  { import = "astrocommunity.programming-language-support.nvim-jqx" },

  -- Reproducible scientific and geospatial reports, with code cells run in a
  -- Jupyter kernel (configured in lua/plugins/molten.lua).
  { import = "astrocommunity.pack.quarto" },
  { import = "astrocommunity.code-runner.molten-nvim" },
}
