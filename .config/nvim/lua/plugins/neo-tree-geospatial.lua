---@type LazySpec
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      local filesystem_commands = require "neo-tree.sources.filesystem.commands"

      -- Opening any recognised image displays metadata. GDAL is first used as
      -- a lightweight probe; spatially referenced images are displayed with
      -- gdalinfo, while ordinary images are displayed with ExifTool.
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

      -- Binary raster/vector datasets are inspected instead of being opened as
      -- text. Text formats such as GeoJSON, KML, GML and VRT still open normally
      -- and can be inspected explicitly with I.
      -- Formats opened directly through snacks.image. Other recognised image
      -- formats (for example camera RAW files) still go to the metadata view.
      local viewable_image_exts = {
        avif = true,
        bmp = true,
        gif = true,
        heic = true,
        icns = true,
        jpeg = true,
        jpg = true,
        png = true,
        svg = true,
        tif = true,
        tiff = true,
        webp = true,
      }

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

      local function extension(path)
        return path:lower():match "%.([a-z0-9]+)$"
      end

      local function is_image(path)
        local ext = extension(path)
        return ext and image_exts[ext] or false
      end

      local function is_viewable_image(path)
        local ext = extension(path)
        return ext and viewable_image_exts[ext] or false
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

      local function has_values(value)
        return type(value) == "table" and next(value) ~= nil
      end

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

      local function display_command(buf, request_id, path, tool, command, filetype)
        if not request_is_current(buf, request_id) then return end

        if vim.fn.executable(tool) ~= 1 then
          set_request_lines(buf, request_id, {
            ("%s is not installed or is not in PATH."):format(tool),
            "Path: " .. path,
          }, "text")
          return
        end

        set_request_lines(buf, request_id, { ("Loading metadata with %s..."):format(tool) }, "text")
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

      local function open_info_in_buffer(path)
        local bufname = "metadata://" .. path
        local existing = vim.fn.bufnr(bufname)
        if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
          vim.api.nvim_set_current_buf(existing)
          return
        end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(buf, bufname)
        vim.api.nvim_set_current_buf(buf)
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].filetype = "text"
        vim.bo[buf].swapfile = false

        vim.keymap.set("n", "q", function()
          if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        end, { buffer = buf, silent = true, desc = "Close metadata" })

        vim.keymap.set("n", "r", function()
          if vim.api.nvim_buf_is_valid(buf) then inspect_dataset(buf, path) end
        end, { buffer = buf, silent = true, desc = "Refresh metadata" })

        inspect_dataset(buf, path)
      end

      local function selected_path(state)
        local node = state.tree:get_node()
        return node and node.type == "file" and node.path or nil
      end

      local function inspect_selected(state)
        local path = selected_path(state)
        if path then open_info_in_buffer(path) end
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

      local function open_or_info(state)
        local node = state.tree:get_node()
        if not node then return end

        if node.type == "file" and node.path then
          -- Images are opened normally so Snacks can render them directly in
          -- Ghostty. Metadata remains available explicitly with the I mapping.
          if is_viewable_image(node.path) then
            filesystem_commands.open(state)
            return
          end

          if is_image(node.path) or is_raster_dataset(node.path) or is_vector_dataset(node.path) then
            open_info_in_buffer(node.path)
            return
          end
        end

        filesystem_commands.open(state)
      end

      opts.filesystem = opts.filesystem or {}
      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = vim.tbl_deep_extend("force", opts.filesystem.window.mappings or {}, {
        ["<cr>"] = open_or_info,
        ["l"] = open_or_info,
        I = inspect_selected,
        Q = open_in_qgis,
      })

      return opts
    end,
  },
}
