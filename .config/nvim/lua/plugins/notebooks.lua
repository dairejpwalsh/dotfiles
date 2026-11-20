-- Open Jupyter notebooks (.ipynb) as Markdown text and save them back as
-- notebooks, through the `jupytext` CLI (python-jupytext on Arch).
--
-- Python notebooks get the "quarto" filetype, so they behave like .qmd files:
-- rendered Markdown, language-server features inside code cells (otter), and
-- the Quarto runner keys that send cells to Molten (lua/plugins/molten.lua).
---@type LazySpec
return {
  "GCBallesteros/jupytext.nvim",
  lazy = false, -- must be set up before the first .ipynb file is opened
  opts = {
    custom_language_formatting = {
      python = { extension = "md", style = "markdown", force_ft = "quarto" },
    },
  },
}
