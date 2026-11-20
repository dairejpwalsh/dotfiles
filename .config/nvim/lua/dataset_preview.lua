-- Commands behind the Neo-tree `E` key (lua/plugins/neo-tree-geospatial.lua):
-- DuckDB printing the first rows of a tabular or spatial dataset, and GDAL
-- rendering a raster as a small PNG. Exercised in CI (.github/scripts/nvim-smoke.lua).
local M = {}

M.limit = 40

-- Formats DuckDB reads natively, by lower-case extension.
local readers = {
  csv = "read_csv",
  tsv = "read_csv",
  parquet = "read_parquet",
  jsonl = "read_json",
  ndjson = "read_json",
}

-- Formats read through GDAL by DuckDB's spatial extension (ST_Read).
local spatial = {
  fgb = true,
  geojson = true,
  gml = true,
  gpkg = true,
  gpx = true,
  kml = true,
  shp = true,
}

local function extension(path) return path:lower():match "%.([a-z0-9]+)$" end

local function sql_string(value) return "'" .. value:gsub("'", "''") .. "'" end

---@param path string
---@return boolean
function M.supports(path)
  local ext = extension(path)
  return ext ~= nil and (readers[ext] ~= nil or spatial[ext] == true)
end

---@param path string
---@param opts? { width?: integer, limit?: integer }
---@return string[]? argv for vim.system, or nil when the format is unsupported
function M.command(path, opts)
  opts = opts or {}
  local ext = extension(path)
  local query
  if ext and readers[ext] then
    query = ("SELECT * FROM %s(%s)"):format(readers[ext], sql_string(path))
  elseif ext and spatial[ext] then
    -- INSTALL downloads the extension on first use and is a no-op afterwards.
    query = ("INSTALL spatial; LOAD spatial; SELECT * FROM ST_Read(%s)"):format(sql_string(path))
  else
    return nil
  end

  return {
    "duckdb",
    -- When not writing to a terminal DuckDB prints every column at full width,
    -- so long values such as WKT geometries would fill the buffer. Fit the
    -- table to the window instead; DuckDB truncates or hides columns to fit.
    "-cmd",
    (".maxwidth %d"):format(opts.width or 200),
    "-c",
    ("%s LIMIT %d;"):format(query, opts.limit or M.limit),
  }
end

---gdal_translate arguments that render a raster as an 8-bit PNG thumbnail.
---@param path string raster to render
---@param info table decoded `gdalinfo -json` output for `path`
---@param out string PNG to write
---@param opts? { size?: integer } longest side in pixels (default 1024)
---@return string[]? argv for vim.system, or nil when the raster has no bands
function M.thumbnail_command(path, info, out, opts)
  opts = opts or {}
  local bands = info.bands or {}
  if #bands == 0 then return nil end

  local command = { "gdal_translate", "-q", "-of", "PNG" }

  -- Shrink large rasters (keeping the aspect ratio); never enlarge small ones.
  local size = opts.size or 1024
  local width, height = (info.size or {})[1] or 0, (info.size or {})[2] or 0
  if width > size or height > size then
    if width >= height then
      vim.list_extend(command, { "-outsize", tostring(size), "0" })
    else
      vim.list_extend(command, { "-outsize", "0", tostring(size) })
    end
  end

  if #bands == 1 and bands[1].colorInterpretation == "Palette" then
    -- Classified rasters (land cover, ...) carry their own colour table.
    vim.list_extend(command, { "-expand", "rgb" })
  else
    -- First three bands as RGB, or the first band as greyscale.
    local selected = #bands >= 3 and { 1, 2, 3 } or { 1 }
    local all_bytes = true
    for _, band in ipairs(selected) do
      vim.list_extend(command, { "-b", tostring(band) })
      if bands[band].type ~= "Byte" then all_bytes = false end
    end
    -- Stretch each band's range to 0-255 so 16-bit and floating-point data
    -- (elevation models, reflectance) are visible rather than black.
    if not all_bytes then vim.list_extend(command, { "-ot", "Byte", "-scale" }) end
  end

  vim.list_extend(command, { path, out })
  return command
end

return M
