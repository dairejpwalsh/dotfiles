---@type vim.lsp.Config
return {
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
}
