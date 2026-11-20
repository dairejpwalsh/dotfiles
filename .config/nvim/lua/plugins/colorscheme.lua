-- Match Ghostty, which switches between Catppuccin Latte and Mocha with the
-- system appearance. Neovim asks the terminal for its background colour at
-- startup and sets 'background'; the "auto" flavour then picks Latte for a
-- light background and Mocha for a dark one.
---@type LazySpec
return {
  {
    "AstroNvim/astroui",
    ---@type AstroUIOpts
    opts = { colorscheme = "catppuccin" },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "auto",
      background = { light = "latte", dark = "mocha" },
    },
  },
}
