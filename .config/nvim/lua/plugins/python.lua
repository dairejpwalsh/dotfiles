-- Overrides for the AstroCommunity Python packs imported in lua/community.lua.
-- Community specs are loaded first, so these values take precedence.
--
-- This is set through AstroLSP rather than after/lsp/basedpyright.lua: the
-- packs configure basedpyright with vim.lsp.config(), and Neovim gives
-- vim.lsp.config() priority over after/lsp/*.lua (see :h lsp-config-merge).
-- A project's pyproject.toml [tool.basedpyright] section still wins over both.
---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    config = {
      basedpyright = {
        settings = {
          basedpyright = {
            -- Ruff owns import sorting and formatting.
            disableOrganizeImports = true,
            analysis = {
              autoImportCompletions = true,
              diagnosticMode = "openFilesOnly",
              typeCheckingMode = "standard",
            },
          },
        },
      },
    },
  },
}
