-- snacks.image only opens files whose extension is in `formats`, matched
-- case-sensitively. Snacks replaces list options rather than merging them, so
-- this restates its defaults, adds `tif` (the usual TIFF/GeoTIFF extension),
-- and adds upper-case variants such as the `.JPG` files cameras produce.
local image_formats = {
  "png",
  "jpg",
  "jpeg",
  "gif",
  "bmp",
  "webp",
  "tiff",
  "tif",
  "heic",
  "avif",
  "mp4",
  "mov",
  "avi",
  "mkv",
  "webm",
  "pdf",
  "icns",
}
for i = 1, #image_formats do
  image_formats[#image_formats + 1] = image_formats[i]:upper()
end

---@type LazySpec
return {
  ---------------------------------------------------------------------------
  -- AstroNvim: mappings + Tree-sitter parsers
  ---------------------------------------------------------------------------
  {
    "AstroNvim/astrocore",
    ---@type AstroCoreOpts
    opts = {
      -- AstroNvim 6 manages Tree-sitter parser installation through AstroCore.
      treesitter = {
        ensure_installed = {
          "markdown",
          "markdown_inline",
          "html",
          "latex",
          "yaml",
        },
      },

      mappings = {
        n = {
          -- Which-key group
          ["<Leader>m"] = { desc = "Markdown" },

          -- Render Markdown inside Neovim
          ["<Leader>mr"] = {
            function() require("render-markdown").buf_toggle() end,
            desc = "Markdown: toggle rendering",
          },

          -- Open a rendered side preview
          ["<Leader>ms"] = {
            function() require("render-markdown").preview() end,
            desc = "Markdown: side preview",
          },

          -- Show the image under the cursor in a floating window
          ["<Leader>mh"] = {
            function() require("snacks").image.hover() end,
            desc = "Markdown: image hover",
          },

          -- Paste clipboard image into ./assets/
          ["<Leader>mp"] = {
            "<Cmd>PasteImage<CR>",
            desc = "Markdown: paste image",
          },

          -- Full browser Markdown preview
          ["<Leader>mb"] = {
            "<Cmd>MarkdownPreviewToggle<CR>",
            desc = "Markdown: browser preview",
          },
        },
      },
    },
  },

  ---------------------------------------------------------------------------
  -- Snacks: inline images inside Markdown / Ghostty
  ---------------------------------------------------------------------------
  {
    "folke/snacks.nvim",
    opts = {
      image = {
        enabled = true,

        formats = image_formats,

        doc = {
          enabled = true,

          -- Render images directly in the Markdown buffer.
          inline = true,

          -- Fallback to floating rendering where inline is unavailable.
          float = true,

          max_width = 80,
          max_height = 40,
        },

        -- Directories Snacks will commonly look in for document images.
        img_dirs = {
          "img",
          "images",
          "assets",
          "static",
          "public",
          "media",
          "attachments",
        },
      },
    },
  },

  ---------------------------------------------------------------------------
  -- Render Markdown: headings, tables, checkboxes, code blocks, links, etc.
  ---------------------------------------------------------------------------
  {
    "MeanderingProgrammer/render-markdown.nvim",

    ft = {
      "markdown",
      "quarto",
      "rmd",
    },

    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },

    ---@module "render-markdown"
    ---@type render.md.UserConfig
    opts = {
      enabled = true,

      file_types = {
        "markdown",
        "quarto",
        "rmd",
      },

      -- Render in normal/command modes but get out of the way while editing.
      render_modes = {
        "n",
        "c",
        "t",
      },

      -- Integrates checkbox/callout completion with AstroNvim's completion.
      completions = {
        lsp = {
          enabled = true,
        },
      },
    },
  },

  ---------------------------------------------------------------------------
  -- img-clip: paste screenshots/images from clipboard
  ---------------------------------------------------------------------------
  {
    "HakonHarnes/img-clip.nvim",

    cmd = {
      "PasteImage",
      "ImgClipDebug",
      "ImgClipConfig",
    },

    ft = {
      "markdown",
      "quarto",
      "rmd",
    },

    opts = {
      default = {
        -- foo.md -> assets/my-image.png
        dir_path = "assets",

        extension = "png",

        -- Store paths relative to the current Markdown document.
        use_absolute_path = false,
        relative_to_current_file = true,

        -- Ask for a useful filename rather than silently using a timestamp.
        prompt_for_file_name = true,

        -- Used if you accept the generated default filename.
        file_name = "%Y-%m-%d-%H-%M-%S",
      },

      filetypes = {
        markdown = {
          url_encode_path = true,
          template = "![$CURSOR]($FILE_PATH)",
          download_images = false,
        },

        quarto = {
          url_encode_path = true,
          template = "![$CURSOR]($FILE_PATH)",
          download_images = false,
        },

        rmd = {
          url_encode_path = true,
          template = "![$CURSOR]($FILE_PATH)",
          download_images = false,
        },
      },
    },
  },

  ---------------------------------------------------------------------------
  -- Browser Markdown preview
  ---------------------------------------------------------------------------
  {
    "iamcco/markdown-preview.nvim",

    cmd = {
      "MarkdownPreviewToggle",
      "MarkdownPreview",
      "MarkdownPreviewStop",
    },

    ft = {
      "markdown",
      "quarto",
      "rmd",
    },

    build = function() vim.fn["mkdp#util#install"]() end,

    init = function()
      vim.g.mkdp_filetypes = {
        "markdown",
        "quarto",
        "rmd",
      }
    end,
  },
}
