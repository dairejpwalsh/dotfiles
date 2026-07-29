---@type LazySpec
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      local image_exts = {
        jpg = true, jpeg = true, png = true, webp = true,
        heic = true, gif = true, bmp = true, avif = true,
        tif = true, tiff = true,
      }

      local function is_image(path)
        local ext = path:lower():match("%.([a-z0-9]+)$")
        return ext and image_exts[ext] or false
      end

      --- Reads a TIFF or BigTIFF header and returns true if GeoKeyDirectoryTag
      --- (34735 / 0x87AF) is present in the first IFD, making it a GeoTIFF.
      local function is_geotiff(path)
        local ext = path:lower():match("%.([a-z0-9]+)$")
        if ext ~= "tif" and ext ~= "tiff" then return false end

        local f = io.open(path, "rb")
        if not f then return false end

        local function bail()
          f:close()
          return false
        end

        -- Need at least 16 bytes to cover the BigTIFF header
        local header = f:read(16)
        if not header or #header < 16 then return bail() end

        local bo = header:sub(1, 2)
        local le = bo == "II"
        if bo ~= "II" and bo ~= "MM" then return bail() end

        local function u16(s, i)
          local a, b = s:byte(i), s:byte(i + 1)
          return le and (a + b * 256) or (a * 256 + b)
        end

        local function u32(s, i)
          local a, b, c, d = s:byte(i), s:byte(i+1), s:byte(i+2), s:byte(i+3)
          return le
            and (a + b*0x100 + c*0x10000 + d*0x1000000)
            or  (a*0x1000000 + b*0x10000 + c*0x100 + d)
        end

        -- u64: Lua numbers are doubles, so we lose precision above 2^53.
        -- In practice IFD offsets in any sane file fit in 32 bits, so we
        -- read the low 32 bits and assert the high 32 bits are zero.
        local function u64(s, i)
          local lo = u32(s, i)
          local hi = u32(s, i + 4)
          if hi ~= 0 then return nil end  -- offset > 4 GB, can't seek
          return lo
        end

        local magic = u16(header, 3)
        local GEO_KEY_TAG = 34735  -- 0x87AF  GeoKeyDirectoryTag

        -- ── Classic TIFF (magic = 42) ────────────────────────────────────────
        -- Header layout (bytes 1-based):
        --   [1-2]  byte order
        --   [3-4]  magic (42)
        --   [5-8]  IFD0 offset (u32)
        -- IFD entry: 12 bytes — tag(u16) type(u16) count(u32) value(u32)
        -- Entry count: u16 immediately before entries
        if magic == 42 then
          local ifd_offset = u32(header, 5)
          f:seek("set", ifd_offset)
          local cb = f:read(2)
          if not cb or #cb < 2 then return bail() end
          local n = u16(cb, 1)
          for _ = 1, n do
            local entry = f:read(12)
            if not entry or #entry < 12 then break end
            if u16(entry, 1) == GEO_KEY_TAG then
              f:close(); return true
            end
          end
          return bail()

        -- ── BigTIFF (magic = 43) ─────────────────────────────────────────────
        -- Header layout (bytes 1-based):
        --   [1-2]  byte order
        --   [3-4]  magic (43)
        --   [5-6]  bytesize of offsets (must be 8)
        --   [7-8]  constant 0
        --   [9-16] IFD0 offset (u64)
        -- IFD entry: 20 bytes — tag(u16) type(u16) count(u64) value(u64)
        -- Entry count: u64 immediately before entries
        elseif magic == 43 then
          local offset_size = u16(header, 5)
          local constant    = u16(header, 7)
          if offset_size ~= 8 or constant ~= 0 then return bail() end

          local ifd_offset = u64(header, 9)
          if not ifd_offset then return bail() end

          f:seek("set", ifd_offset)
          local cb = f:read(8)
          if not cb or #cb < 8 then return bail() end

          local n = u64(cb, 1)
          if not n then return bail() end

          for _ = 1, n do
            local entry = f:read(20)
            if not entry or #entry < 20 then break end
            if u16(entry, 1) == GEO_KEY_TAG then
              f:close(); return true
            end
          end
          return bail()

        else
          return bail()
        end
      end

      local function open_info_in_buffer(path)
        local geo = is_geotiff(path)
        local tool = geo and "gdalinfo" or "exiftool"
        local bufname = ("%s://%s"):format(tool, path)

        local existing = vim.fn.bufnr(bufname)
        if existing ~= -1 then
          vim.api.nvim_set_current_buf(existing)
          return
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, bufname)
        vim.api.nvim_set_current_buf(buf)
        vim.bo[buf].buftype    = "nofile"
        vim.bo[buf].bufhidden  = "wipe"
        vim.bo[buf].filetype   = geo and "gdalinfo" or "exif"
        vim.bo[buf].modifiable = true

        local cmd = geo
          and { "gdalinfo", path }
          or  { "exiftool", "-G", "-a", "-s", path }

        local out = vim.fn.systemlist(cmd)
        if vim.v.shell_error ~= 0 then
          out = {
            ("%s failed (is it installed and in PATH?)"):format(tool),
            "Path: " .. path,
          }
        end

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
        vim.bo[buf].modifiable = false
      end

      local function open_or_info(state)
        local node = state.tree:get_node()
        if not node or node.type ~= "file" then return end
        local path = node.path
        if path and is_image(path) then
          open_info_in_buffer(path)
          return
        end
        require("neo-tree.sources.filesystem.commands").open(state)
      end

      opts.filesystem = opts.filesystem or {}
      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = vim.tbl_deep_extend(
        "force",
        opts.filesystem.window.mappings or {},
        {
          ["<cr>"] = open_or_info,
          ["l"]    = open_or_info,
        }
      )
      return opts
    end,
  },
}
