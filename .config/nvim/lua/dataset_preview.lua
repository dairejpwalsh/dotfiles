-- DuckDB commands that print the first rows of a tabular or spatial dataset.
-- Used by the Neo-tree `E` key (lua/plugins/neo-tree-geospatial.lua) and
-- exercised in CI (.github/scripts/nvim-smoke.lua).
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

return M
