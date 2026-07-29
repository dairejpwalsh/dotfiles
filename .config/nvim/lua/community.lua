-- AstroCommunity modules are imported before the local plugins directory so
-- local plugin specifications can override their defaults when necessary.
---@type LazySpec
return {
  "AstroNvim/astrocommunity",

  -- Python: BasedPyright, Ruff, debugpy, virtual environments and pytest.
  { import = "astrocommunity.pack.python-ruff" },

  -- Project and geospatial data formats.
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.yaml" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.xml" },

  -- SQL/PostGIS editing and database access.
  { import = "astrocommunity.pack.sql" },
  { import = "astrocommunity.pack.full-dadbod" },

  -- Large structured files and data inspection.
  { import = "astrocommunity.editing-support.bigfile-nvim" },
  { import = "astrocommunity.programming-language-support.csv-vim" },
  { import = "astrocommunity.programming-language-support.nvim-jqx" },

  -- Reproducible scientific and geospatial reports.
  { import = "astrocommunity.pack.quarto" },
}
