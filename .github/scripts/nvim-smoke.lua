-- Headless smoke test for the Neovim configuration, run by CI once the plugins
-- are installed:
--
--   nvim --headless -c "luafile .github/scripts/nvim-smoke.lua"
--
-- It fails on plugin spec errors and errors raised while loading plugins, and
-- checks the settings that are easy to break silently. Exits non-zero with a
-- list of failures.

local failures = {}
local function check(ok, message)
  if not ok then table.insert(failures, message) end
end
local function out(text) io.stdout:write(text .. "\n") end
-- Progress goes to stderr, which is unbuffered, so a hang shows where it stopped.
local function progress(text) io.stderr:write("[smoke] " .. text .. "\n") end
progress "started"

-- Errors reported from here on, while every plugin is force-loaded below.
local notify = vim.notify
vim.notify = function(msg, level, opts) ---@diagnostic disable-line: duplicate-set-field
  if level and level >= vim.log.levels.ERROR then table.insert(failures, "notify: " .. tostring(msg)) end
  return notify(msg, level, opts)
end

-- 1. lazy.nvim spec problems, such as importing a module that no longer exists.
local lazy_config = require "lazy.core.config"
for _, notif in ipairs(lazy_config.spec.notifs or {}) do
  if notif.level >= vim.log.levels.WARN then table.insert(failures, ("lazy spec: %s"):format(notif.msg)) end
end

-- 2. Load every plugin, so configuration errors in lazily loaded plugins
--    surface here rather than on first use.
local names = vim.tbl_keys(lazy_config.plugins)
table.sort(names)
for _, name in ipairs(names) do
  progress("loading " .. name)
  local ok, err = pcall(require("lazy").load, { plugins = { name } })
  check(ok, ("loading %s: %s"):format(name, err))
end
progress(("loaded %d plugins; checking settings"):format(#names))

-- 3. Settings.
check(lazy_config.plugins["bigfile.nvim"] == nil, "bigfile.nvim should not be installed")
for _, module in ipairs { "venv-selector", "neotest", "dap-python" } do
  check(pcall(require, module), "Python pack module missing: " .. module)
end

local basedpyright = vim.lsp.config.basedpyright or {}
local settings = vim.tbl_get(basedpyright, "settings", "basedpyright") or {}
check(
  vim.tbl_get(settings, "analysis", "typeCheckingMode") == "standard",
  "basedpyright typeCheckingMode should be standard (lua/plugins/python.lua)"
)
check(settings.disableOrganizeImports == true, "basedpyright should leave import sorting to Ruff")

check(
  (vim.g.colors_name or ""):match "^catppuccin" ~= nil,
  "colorscheme should be catppuccin, got " .. tostring(vim.g.colors_name)
)

local formats = require("snacks").image.config.formats or {}
for _, format in ipairs { "png", "tif", "tiff", "JPG" } do
  check(vim.tbl_contains(formats, format), "snacks.image formats should include " .. format)
end

check(vim.fn.exists ":MoltenInit" == 2, ":MoltenInit is missing (pynvim, or :UpdateRemotePlugins not run)")
local function mapping(lhs, mode) return vim.fn.maparg(lhs, mode or "n", false, true) end
check((mapping("<Leader>je").desc or ""):find "Run operator" ~= nil, "Molten keys should be under <Leader>j")
check((mapping("]j").desc or ""):find "Molten" ~= nil, "Molten cell jumps should be ]j/[j")
check(next(mapping "]c") == nil, "]c should be left to Vim's diff navigation")
check((mapping("<Leader>mr").desc or ""):find "Markdown" ~= nil, "Markdown keys should stay under <Leader>m")

local neo_tree_maps = vim.tbl_get(require("neo-tree").config, "filesystem", "window", "mappings") or {}
for _, key in ipairs { "<cr>", "l", "I", "E", "Q" } do
  check(neo_tree_maps[key] ~= nil, "Neo-tree filesystem mapping missing: " .. key)
end

-- 4. DuckDB row previews against sample files (quote in a name on purpose).
local preview = require "dataset_preview"
local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
local csv = dir .. "/sample.csv"
vim.fn.writefile({ "id,name", "1,alpha", "2,beta" }, csv)
local geojson = dir .. "/points.geojson"
vim.fn.writefile({
  '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"site":"delta"},'
    .. '"geometry":{"type":"Point","coordinates":[-6.26,53.35]}}]}',
}, geojson)
local parquet = dir .. "/it's.parquet"
local made = vim
  .system({
    "duckdb",
    "-c",
    ("COPY (SELECT 42 AS answer, 'gamma' AS label) TO '%s' (FORMAT parquet)"):format((parquet:gsub("'", "''"))),
  }, { text = true })
  :wait()
check(made.code == 0, "could not create sample Parquet: " .. (made.stderr or ""))

for path, expected in pairs { [csv] = "alpha", [parquet] = "gamma", [geojson] = "delta" } do
  progress("previewing " .. vim.fn.fnamemodify(path, ":t"))
  local command = preview.command(path, { width = 100 })
  if not command then
    check(false, "no preview command for " .. path)
  else
    local result = vim.system(command, { text = true }):wait(120000)
    local ok = result.code == 0 and (result.stdout or ""):find(expected, 1, true) ~= nil
    check(ok, ("preview of %s failed (exit %s):\n%s%s"):format(path, result.code, result.stdout, result.stderr))
    if ok then out(("Preview of %s:\n%s"):format(vim.fn.fnamemodify(path, ":t"), result.stdout)) end
  end
end
check(not preview.supports(dir .. "/notes.txt"), "plain text should not have a row preview")

-- Report.
local messages = vim.api.nvim_exec2("messages", { output = true }).output
if messages ~= "" then out("Messages:\n" .. messages) end

if #failures > 0 then
  io.stderr:write(("Smoke test FAILED (%d):\n- %s\n"):format(#failures, table.concat(failures, "\n- ")))
  vim.cmd "cquit 1"
else
  out "Smoke test passed"
  vim.cmd "qall!"
end
