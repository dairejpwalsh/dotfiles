-- Run code against a Jupyter kernel with output (and plots) shown inline:
-- Molten, imported from AstroCommunity in lua/community.lua, plus Quarto's
-- code runner sending .qmd chunks through it.
--
-- Requirements:
-- - pynvim and jupyter_client for the system Python (python-pynvim and
--   python-jupyter-client on Arch), then :UpdateRemotePlugins once.
-- - ipykernel in each project environment (`uv add --dev ipykernel`).
---@type LazySpec
return {
  {
    "benlubas/molten-nvim",
    init = function()
      -- Molten is a Python remote plugin. Pin its host to the system Python:
      -- direnv puts project environments first on PATH, and those normally do
      -- not have pynvim. Kernels still run in the project environment.
      if vim.fn.executable "/usr/bin/python3" == 1 then vim.g.python3_host_prog = "/usr/bin/python3" end

      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      -- Keep results as virtual text under each cell rather than popping up a
      -- window whenever the cursor enters a cell.
      vim.g.molten_auto_open_output = false
      vim.g.molten_virt_text_output = true
      -- Show output below a Quarto chunk's closing ``` fence.
      vim.g.molten_virt_lines_off_by_1 = true
    end,
  },

  -- Plot rendering for Molten only. snacks.image (lua/plugins/markdown.lua)
  -- already renders Markdown images and opens image files, so image.nvim's
  -- own integrations and file takeover are switched off.
  {
    "3rd/image.nvim",
    lazy = true, -- loaded by Molten when it first draws a plot
    build = false, -- magick_cli uses the ImageMagick CLI, not the LuaRocks binding
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      integrations = {
        markdown = { enabled = false },
        asciidoc = { enabled = false },
        typst = { enabled = false },
        neorg = { enabled = false },
        syslang = { enabled = false },
      },
      hijack_file_patterns = false,
      max_height_window_percentage = 50,
    },
  },

  -- Run Quarto chunks through Molten, with Quarto's suggested local keys.
  {
    "quarto-dev/quarto-nvim",
    opts = {
      codeRunner = { enabled = true, default_method = "molten" },
    },
  },

  {
    "AstroNvim/astrocore",
    ---@param opts AstroCoreOpts
    opts = function(_, opts)
      -- The community Molten module maps its keys under <leader>m, where
      -- lua/plugins/markdown.lua keeps the Markdown keys (written <Leader>m),
      -- and maps ]c/[c, which hides Vim's jump to the next diff change. Move
      -- them to <Leader>j (Jupyter) and ]j/[j.
      for _, mode in ipairs { "n", "v" } do
        local maps = opts.mappings and opts.mappings[mode]
        if maps then
          local moves = {} -- { from, to } pairs; the table can't change mid-pairs()
          for lhs, map in pairs(maps) do
            local rest = lhs:match "^<leader>m(.*)$"
            if rest then
              table.insert(moves, { lhs, "<Leader>j" .. rest })
            elseif (lhs == "]c" or lhs == "[c") and type(map) == "table" and tostring(map[1]):find "Molten" then
              table.insert(moves, { lhs, lhs:sub(1, 1) .. "j" })
            end
          end
          for _, move in ipairs(moves) do
            maps[move[2]] = maps[move[1]]
            maps[move[1]] = nil
          end
        end
      end

      opts.autocmds = opts.autocmds or {}
      opts.autocmds.quarto_runner_keys = {
        {
          event = "FileType",
          pattern = "quarto",
          desc = "Quarto code runner keys",
          callback = function(args)
            local function map(mode, lhs, fn, desc)
              vim.keymap.set(
                mode,
                lhs,
                function() require("quarto.runner")[fn]() end,
                { buffer = args.buf, silent = true, desc = desc }
              )
            end
            map("n", "<LocalLeader>rc", "run_cell", "Run cell")
            map("n", "<LocalLeader>ra", "run_above", "Run cell and above")
            map("n", "<LocalLeader>rA", "run_all", "Run all cells")
            map("n", "<LocalLeader>rl", "run_line", "Run line")
            map("v", "<LocalLeader>r", "run_range", "Run visual range")
          end,
        },
      }
    end,
  },
}
