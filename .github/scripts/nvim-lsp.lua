-- Checks that the Python language servers actually run: opens a file with a
-- type error and an unused import, then waits for BasedPyright and Ruff to
-- attach and report them. Run by CI after `:MasonInstall basedpyright ruff`:
--
--   nvim --headless -c "luafile .github/scripts/nvim-lsp.lua"

local failures = {}
local function check(ok, message)
  if not ok then table.insert(failures, message) end
end
local function progress(text) io.stderr:write("[lsp] " .. text .. "\n") end

local function run()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local file = dir .. "/sample.py"
  vim.fn.writefile({ "import os", "", 'answer: int = "not a number"', "" }, file)

  progress("opening " .. file)
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  local buf = vim.api.nvim_get_current_buf()

  local function clients()
    local names = {}
    for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
      names[client.name] = true
    end
    return names
  end
  local attached = vim.wait(180000, function()
    local names = clients()
    return names.basedpyright and names.ruff
  end, 500)
  local names = vim.tbl_keys(clients())
  table.sort(names)
  progress("attached: " .. table.concat(names, ", "))
  check(attached, "BasedPyright and Ruff should attach; attached: " .. table.concat(names, ", "))
  if not attached then return end

  local function find(source, pattern)
    for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
      local text = ("%s %s"):format(diagnostic.code or "", diagnostic.message)
      if (diagnostic.source or ""):lower():find(source, 1, true) and text:find(pattern) then return true end
    end
    return false
  end
  local reported = vim.wait(180000, function() return find("basedpyright", "int") and find("ruff", "F401") end, 500)
  for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
    progress(("%s: %s %s"):format(diagnostic.source, diagnostic.code or "", diagnostic.message))
  end
  check(reported, "expected a BasedPyright type error and Ruff F401 (unused import)")
end

local ok, err = xpcall(run, debug.traceback)
check(ok, "LSP script error: " .. tostring(err))

if #failures > 0 then
  io.stderr:write(("LSP check FAILED:\n- %s\n"):format(table.concat(failures, "\n- ")))
  vim.cmd "cquit 1"
else
  io.stdout:write "LSP check passed\n"
  vim.cmd "qall!"
end
