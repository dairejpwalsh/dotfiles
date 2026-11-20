---@type LazySpec
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      local filesystem_commands = require "neo-tree.sources.filesystem.commands"

      -- Recognised image formats. Opening one shows the picture through
      -- snacks.image when Snacks can render it, and the metadata view
      -- otherwise (camera RAW files, GeoTIFFs, ...). In the metadata view GDAL
      -- is first used as a lightweight probe; spatially referenced images are
      -- displayed with gdalinfo, while ordinary images use ExifTool.
      local image_exts = {
        ["3fr"] = true,
        ari = true,
        arw = true,
        avif = true,
        bay = true,
        bmp = true,
        cap = true,
        cine = true,
        cr2 = true,
        cr3 = true,
        crw = true,
        cs1 = true,
        dc2 = true,
        dcr = true,
        dng = true,
        drf = true,
        eip = true,
        eps = true,
        erf = true,
        fff = true,
        gif = true,
        heic = true,
        heif = true,
        icns = true,
        ico = true,
        iiq = true,
        j2k = true,
        jpeg = true,
        jpg = true,
        jp2 = true,
        jpf = true,
        jpm = true,
        jpx = true,
        k25 = true,
        kdc = true,
        mef = true,
        mos = true,
        mrw = true,
        nef = true,
        nrw = true,
        orf = true,
        pbm = true,
        pef = true,
        pgm = true,
        png = true,
        pnm = true,
        ppm = true,
        psd = true,
        raf = true,
        raw = true,
        rw2 = true,
        rwl = true,
        rwz = true,
        sr2 = true,
        srf = true,
        srw = true,
        svg = true,
        svgz = true,
        tga = true,
        tif = true,
        tiff = true,
        webp = true,
        x3f = true,
        xcf = true,
      }

      -- Images that are also text (SVG is XML) open for editing as usual.
      local text_image_exts = { svg = true }

      -- Binary raster/vector datasets are inspected instead of being opened as
      -- text. Text formats such as GeoJSON, KML, GML and VRT still open normally
      -- and can be inspected explicitly with I.
      local raster_dataset_exts = {
        asc = true,
        bil = true,
        bip = true,
        bsq = true,
        dem = true,
        dt0 = true,
        dt1 = true,
        dt2 = true,
        grd = true,
        h5 = true,
        hdf = true,
        hdf4 = true,
        hdf5 = true,
        img = true,
        kea = true,
        mbtiles = true,
        nc = true,
        nitf = true,
        ntf = true,
        pix = true,
        sid = true,
      }

      local vector_dataset_exts = {
        db = true,
        fgb = true,
        gpkg = true,
        parquet = true,
        shp = true,
        sqlite = true,
      }

      local text_vector_exts = {
        geojson = true,
        gml = true,
        json = true,
        kml = true,
      }

      local text_raster_exts = { vrt = true }

      local function extension(path) return path:lower():match "%.([a-z0-9]+)$" end

      local function is_image(path)
        local ext = extension(path)
        return ext and image_exts[ext] or false
      end

      local function is_text_image(path)
        local ext = extension(path)
        return ext and text_image_exts[ext] or false
      end

      local function is_tiff(path)
        local ext = extension(path)
        return ext == "tif" or ext == "tiff"
      end

      -- snacks.image only takes over a file through a BufReadCmd autocmd built
      -- from its `formats` option, and that match is case-sensitive. Any image
      -- it does not intercept would be read into a buffer as raw binary, so
      -- check the extension exactly as written. (lua/plugins/markdown.lua adds
      -- `tif` and upper-case variants to the formats.)
      local function snacks_can_display(path)
        local ext = path:match "%.([^./]+)$"
        if not ext then return false end
        local ok, formats = pcall(function()
          local config = require("snacks").image.config
          return config.enabled ~= false and config.formats or {}
        end)
        return ok and vim.tbl_contains(formats, ext)
      end

      local function is_raster_dataset(path)
        local ext = extension(path)
        return ext and raster_dataset_exts[ext] or false
      end

      local function is_vector_dataset(path)
        local ext = extension(path)
        return ext and vector_dataset_exts[ext] or false
      end

      local function is_text_raster(path)
        local ext = extension(path)
        return ext and text_raster_exts[ext] or false
      end

      local function is_text_vector(path)
        local ext = extension(path)
        return ext and text_vector_exts[ext] or false
      end

      local function split_lines(text)
        local lines = vim.split(text or "", "\n", { plain = true })
        while #lines > 0 and lines[#lines] == "" do
          table.remove(lines)
        end
        return lines
      end

      local function set_buffer_lines(buf, lines, filetype)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        if #lines == 0 then lines = { "No metadata returned." } end

        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        if filetype then vim.bo[buf].filetype = filetype end
      end

      local next_request_id = 0

      local function begin_request(buf)
        next_request_id = next_request_id + 1
        vim.b[buf].neo_tree_metadata_request_id = next_request_id
        return next_request_id
      end

      local function request_is_current(buf, request_id)
        return vim.api.nvim_buf_is_valid(buf) and vim.b[buf].neo_tree_metadata_request_id == request_id
      end

      local function set_request_lines(buf, request_id, lines, filetype)
        if request_is_current(buf, request_id) then set_buffer_lines(buf, lines, filetype) end
      end

      local function run(command, callback)
        vim.system(command, { text = true }, function(result)
          vim.schedule(function() callback(result) end)
        end)
      end

      local function command_failure(tool, path, result)
        local lines = {
          ("%s failed with exit code %d."):format(tool, result.code or -1),
          "Path: " .. path,
        }
        local stderr = split_lines(result.stderr)
        if #stderr > 0 then
          table.insert(lines, "")
          vim.list_extend(lines, stderr)
        end
        return lines
      end

      local function has_values(value) return type(value) == "table" and next(value) ~= nil end

      local function has_geotransform(value)
        if type(value) ~= "table" then return false end
        for index = 1, 6 do
          if type(value[index]) ~= "number" then return false end
        end
        return true
      end

      local function has_gcps(value)
        if type(value) ~= "table" then return false end
        if type(value.gcpList) == "table" then return next(value.gcpList) ~= nil end
        return next(value) ~= nil
      end

      local function is_spatial_gdal_json(stdout)
        local ok, info = pcall(vim.json.decode, stdout or "")
        if not ok or type(info) ~= "table" then return false end

        -- GDAL can emit a STAC section for an ordinary JPEG, PNG, or other
        -- image. STAC metadata alone therefore does not prove that the raster
        -- is georeferenced. Require an actual spatial-placement signal.
        if has_geotransform(info.geoTransform) then return true end
        if has_gcps(info.gcps) then return true end
        if has_values(info.wgs84Extent) then return true end

        if type(info.metadata) == "table" then
          if has_values(info.metadata.GEOLOCATION) or has_values(info.metadata.RPC) then return true end
        end

        return false
      end

      -- TIFF is both an ordinary image format and the usual GeoTIFF container.
      -- GeoTIFFs are often large, multi-band or floating point, and render
      -- slowly and poorly as pictures, so only plain TIFFs open in the image
      -- viewer. The gdalinfo header probe is normally instant; if it fails or
      -- takes over two seconds, fall back to the metadata view.
      local function is_plain_tiff(path)
        if vim.fn.executable "gdalinfo" ~= 1 then return true end
        local result = vim.system({ "gdalinfo", "-json", path }, { text = true }):wait(2000)
        return result.code == 0 and not is_spatial_gdal_json(result.stdout)
      end

      local function display_command(buf, request_id, path, tool, command, filetype)
        if not request_is_current(buf, request_id) then return end

        if vim.fn.executable(tool) ~= 1 then
          set_request_lines(buf, request_id, {
            ("%s is not installed or is not in PATH."):format(tool),
            "Path: " .. path,
          }, "text")
          return
        end

        set_request_lines(buf, request_id, { ("Running %s..."):format(tool) }, "text")
        run(command, function(result)
          if not request_is_current(buf, request_id) then return end
          if result.code == 0 then
            set_request_lines(buf, request_id, split_lines(result.stdout), filetype)
          else
            set_request_lines(buf, request_id, command_failure(tool, path, result), "text")
          end
        end)
      end

      local function display_exif(buf, request_id, path, prefix)
        if not request_is_current(buf, request_id) then return end

        if vim.fn.executable "exiftool" ~= 1 then
          local lines = vim.deepcopy(prefix or {})
          vim.list_extend(lines, {
            "ExifTool is not installed or is not in PATH.",
            "Path: " .. path,
          })
          set_request_lines(buf, request_id, lines, "text")
          return
        end

        set_request_lines(buf, request_id, { "Loading metadata with ExifTool..." }, "text")
        run({ "exiftool", "-G", "-a", "-s", path }, function(result)
          if not request_is_current(buf, request_id) then return end
          if result.code == 0 then
            local lines = vim.deepcopy(prefix or {})
            if #lines > 0 then table.insert(lines, "") end
            vim.list_extend(lines, split_lines(result.stdout))
            set_request_lines(buf, request_id, lines, "text")
          else
            set_request_lines(buf, request_id, command_failure("exiftool", path, result), "text")
          end
        end)
      end

      local function inspect_image(buf, request_id, path)
        if not request_is_current(buf, request_id) then return end

        if vim.fn.executable "gdalinfo" ~= 1 then
          display_exif(buf, request_id, path, {
            "gdalinfo is unavailable; spatial-image detection was skipped.",
          })
          return
        end

        set_request_lines(buf, request_id, { "Checking for spatial referencing with gdalinfo..." }, "text")
        run({ "gdalinfo", "-json", path }, function(result)
          if not request_is_current(buf, request_id) then return end

          if result.code == 0 and is_spatial_gdal_json(result.stdout) then
            display_command(buf, request_id, path, "gdalinfo", { "gdalinfo", path }, "gdalinfo")
          else
            display_exif(buf, request_id, path)
          end
        end)
      end

      local function inspect_dataset(buf, path)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        local request_id = begin_request(buf)

        if is_image(path) then
          inspect_image(buf, request_id, path)
        elseif is_raster_dataset(path) or is_text_raster(path) then
          display_command(buf, request_id, path, "gdalinfo", { "gdalinfo", path }, "gdalinfo")
        elseif is_vector_dataset(path) or is_text_vector(path) then
          display_command(buf, request_id, path, "ogrinfo", { "ogrinfo", "-al", "-so", path }, "ogrinfo")
        else
          display_exif(buf, request_id, path)
        end
      end

      -- First rows of a table or spatial dataset, via DuckDB, sized to the
      -- window the preview is shown in.
      local function preview_rows(buf, path)
        if not vim.api.nvim_buf_is_valid(buf) then return end
        local request_id = begin_request(buf)
        local win = vim.fn.bufwinid(buf)
        local width = win ~= -1 and vim.api.nvim_win_get_width(win) or 200
        local command = require("dataset_preview").command(path, { width = width })
        if not command then
          set_request_lines(buf, request_id, { "No row preview for this file type.", "Path: " .. path }, "text")
          return
        end
        display_command(buf, request_id, path, "duckdb", command, "text")
      end

      -- Exact name lookup. vim.fn.bufnr() treats its argument as a file
      -- pattern and accepts partial matches, so "a.tif" could find "a.tiff".
      local function find_buffer(name)
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_get_name(buf) == name then return buf end
        end
      end

      -- Neo-tree evicts any other buffer shown in its sidebar window by
      -- deleting it and editing it again by name, which would destroy a
      -- scratch buffer. Show it in the window Neo-tree would open a file in.
      local function show_buffer(state, buf)
        local win = vim.fn.bufwinid(buf)
        if win == -1 then
          if state.current_position == "current" then
            -- Neo-tree is in the editor window itself, so replacing it is expected.
            win = vim.api.nvim_get_current_win()
          else
            local target, is_neo_tree = require("neo-tree.utils").get_appropriate_window(state)
            if is_neo_tree then
              -- Only the tree is open: split beside it instead.
              local side = state.current_position == "right" and "left" or "right"
              vim.api.nvim_open_win(buf, true, { split = side, win = -1 })
              return
            end
            win = target
          end
          vim.api.nvim_win_set_buf(win, buf)
        end
        vim.api.nvim_set_current_win(win)
      end

      -- Opens (or focuses) a read-only scratch buffer named `scheme .. path`
      -- and fills it with `render(buf, path)`. `r` re-renders, `q` closes.
      local function open_view(state, scheme, path, render)
        local bufname = scheme .. path
        local existing = find_buffer(bufname)
        if existing then
          show_buffer(state, existing)
          return
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, bufname)
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].filetype = "text"
        vim.bo[buf].swapfile = false

        vim.keymap.set("n", "q", function()
          if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        end, { buffer = buf, silent = true, desc = "Close" })

        vim.keymap.set("n", "r", function()
          if vim.api.nvim_buf_is_valid(buf) then render(buf, path) end
        end, { buffer = buf, silent = true, desc = "Refresh" })

        show_buffer(state, buf)
        render(buf, path)
      end

      local function open_info_in_buffer(state, path) open_view(state, "metadata://", path, inspect_dataset) end

      local function selected_path(state)
        local node = state.tree:get_node()
        return node and node.type == "file" and node.path or nil
      end

      local function inspect_selected(state)
        local path = selected_path(state)
        if path then open_info_in_buffer(state, path) end
      end

      local function preview_selected(state)
        local path = selected_path(state)
        if not path then return end
        if not require("dataset_preview").supports(path) then
          vim.notify("No row preview for " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
          return
        end
        open_view(state, "rows://", path, preview_rows)
      end

      local function open_in_qgis(state)
        local path = selected_path(state)
        if not path then return end

        local command
        if vim.fn.executable "qgis" == 1 then
          command = { "qgis", path }
        elseif vim.fn.has "mac" == 1 and vim.fn.executable "open" == 1 then
          command = { "open", "-a", "QGIS", path }
        else
          vim.notify("QGIS is not installed or is not in PATH", vim.log.levels.WARN)
          return
        end

        local job = vim.fn.jobstart(command, { detach = true })
        if job <= 0 then vim.notify("Unable to start QGIS", vim.log.levels.ERROR) end
      end

      -- Builds a mapping that shows images through snacks.image and opens
      -- binary GIS datasets in the metadata view. Anything else (directories,
      -- ordinary files) runs `fallback`, the Neo-tree command the key would
      -- otherwise run, so `l` keeps AstroNvim's child_or_open behaviour.
      local function open_or_info(fallback)
        return function(state)
          if not state.tree:get_node() then return end

          local path = selected_path(state)
          if path then
            if is_image(path) and not is_text_image(path) then
              if snacks_can_display(path) and (not is_tiff(path) or is_plain_tiff(path)) then
                filesystem_commands.open(state)
              else
                open_info_in_buffer(state, path)
              end
              return
            end

            if is_raster_dataset(path) or is_vector_dataset(path) then
              open_info_in_buffer(state, path)
              return
            end
          end

          local command = state.commands and state.commands[fallback] or filesystem_commands.open
          command(state)
        end
      end

      opts.filesystem = opts.filesystem or {}
      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = vim.tbl_deep_extend("force", opts.filesystem.window.mappings or {}, {
        ["<cr>"] = open_or_info "open",
        l = open_or_info "child_or_open",
        I = inspect_selected,
        E = preview_selected,
        Q = open_in_qgis,
      })

      return opts
    end,
  },
}
