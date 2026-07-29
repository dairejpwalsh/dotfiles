-- Setup that runs after Lazy/AstroNvim initialization.

vim.filetype.add {
  extension = {
    geojson = "json",
    vrt = "xml",
  },
  filename = {
    ["environment.yml"] = "yaml",
    ["environment.yaml"] = "yaml",
  },
}

local data_file_settings = vim.api.nvim_create_augroup("geospatial_data_file_settings", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = data_file_settings,
  pattern = { "json", "yaml", "quarto" },
  callback = function(args)
    vim.bo[args.buf].expandtab = true
    vim.bo[args.buf].shiftwidth = 2
    vim.bo[args.buf].softtabstop = 2
    vim.bo[args.buf].tabstop = 2
  end,
})
