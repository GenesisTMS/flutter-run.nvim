-- todo
--
-- [ ] on error show window with message (do not print to console) (configurable)
-- [ ] name buffer
-- [ ] catch input to buffer to send it to process
local api = vim.api
local loop = vim.loop
local M = {}

local handle
local pid
local stdin = loop.new_pipe(false)
local stdout = loop.new_pipe(false)
local stderr = loop.new_pipe(false)

local buf
local win

local function createBuf()
  return api.nvim_create_buf(false, true)
end

local function appendLine(line)
  line = line:gsub('\n', '') -- remove line break
  api.nvim_buf_set_lines(buf, -1, -1, false, {line})
end

local function clear()
  print('clearing')
  if buf then api.nvim_buf_delete(buf, {force = true}) end
  buf = nil
  win = nil
end

function M.run(workingDirectory)
  if handle and handle:is_closing() then
    print('Flutter is already runnng')
    return
  end

  workingDirectory = workingDirectory or vim.fn.getcwd()
  buf = createBuf()

  handle, pid = loop.spawn('flutter', {args = {'run'}, stdio = {stdin, stdout, stderr}, cwd = workingDirectory},
                           vim.schedule_wrap(function()
    print('flutter stopped')

    stdout:read_stop()
    stderr:read_stop()
    stdin:close()
    stdout:close()
    stderr:close()
    handle:close()
    clear()
  end))

  print('Flutter started', handle, pid)

  loop.read_start(stdout, vim.schedule_wrap(function(err, data)
    assert(not err, err)
    if data then appendLine(data) end
  end))

  loop.read_start(stderr, vim.schedule_wrap(function(err, data)
    assert(not err, err)
    if data then appendLine('[ERR] ' .. data) end
  end))

  return handle, pid
end

function M.attach(to)
  if not buf then print('Flutter is not running') end
  assert(type(to), 'string')
  vim.cmd(to or 'botright new')
  win = api.nvim_get_current_win()
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].colorcolumn = ""
  vim.wo[win].cursorline = false
  local tb = api.nvim_get_current_buf()
  api.nvim_win_set_buf(win, buf)
  api.nvim_buf_delete(tb, {force = true})
end

function M.send(c)
  if handle and not handle:is_closing() then stdin:write(c) end
end

function M.hotreload()
  M.send('r')
end

function M.stop()
  if handle and not handle:is_closing() then
    handle:close()
    if buf then clear() end
  end
end

return M
