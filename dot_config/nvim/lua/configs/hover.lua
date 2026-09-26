-- VSCode-style hover: one popup with the diagnostics under the mouse (or cursor)
-- on top, then the language server's hover (type, signature, docs) below.
--
-- Mouse: rest the pointer on a symbol for DELAY ms. The popup stays while the
-- pointer is on that symbol or inside the popup (scroll it, click in to select
-- and copy), and closes when the pointer leaves or the window scrolls.
-- Keyboard: K shows the same popup at the cursor; K again jumps into it (q closes).

local M = {}

local api = vim.api
local DELAY = 350
local FOCUS_ID = "hover_popup"
local ns = api.nvim_create_namespace "hover_popup"

local timer = assert(vim.uv.new_timer())
local state = {
  win = nil, -- the popup
  key = nil, -- what the popup (or the pending request) describes, see target()
  src_win = nil, -- window the popup belongs to
}

local function close()
  if state.win and api.nvim_win_is_valid(state.win) then
    pcall(api.nvim_win_close, state.win, true)
  end
  state.win, state.key, state.src_win = nil, nil, nil
end

-- Diagnostics whose range covers (row, col), most severe first.
local function diagnostics_at(buf, row, col)
  local found = {}
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    local end_row, end_col = d.end_lnum or d.lnum, d.end_col or d.col
    -- zero-width ranges (e.g. "expected expression" at end of line) still cover their column
    if d.lnum == end_row and end_col <= d.col then
      end_col = d.col + 1
    end
    local after_start = row > d.lnum or (row == d.lnum and col >= d.col)
    local before_end = row < end_row or (row == end_row and col < end_col)
    if after_start and before_end then
      found[#found + 1] = d
    end
  end
  table.sort(found, function(a, b)
    return a.severity < b.severity
  end)
  return found
end

local severity_hl = { "DiagnosticError", "DiagnosticWarn", "DiagnosticInfo", "DiagnosticHint" }
local severity_icon = { "E", "W", "I", "H" }

-- Markdown lines for the diagnostics, plus the highlights to put on them.
-- Lines are never blank, so open_floating_preview keeps their indices.
local function render_diagnostics(diags)
  local signs = vim.diagnostic.config().signs
  signs = type(signs) == "table" and signs.text or {}
  local lines, marks = {}, {}
  for _, d in ipairs(diags) do
    local icon = signs[d.severity] or severity_icon[d.severity]
    local msg = vim.tbl_filter(function(l)
      return l:find "%S"
    end, vim.split(d.message, "\n"))
    local first = #lines
    for i, l in ipairs(msg) do
      lines[#lines + 1] = (i == 1 and icon .. " " or "  ") .. l
    end
    marks[#marks + 1] = { first, 0, #icon, severity_hl[d.severity] }

    local src = d.source and d.code and ("%s(%s)"):format(d.source, d.code) or d.source or d.code
    if src then
      local last = lines[#lines]
      lines[#lines] = last .. "  " .. src
      marks[#marks + 1] = { #lines - 1, #last + 2, #lines[#lines], "Comment" }
    end
  end
  return lines, marks
end

-- Put the popup under the pointer when there's room, else above it.
local function place_at_mouse(win)
  local mouse = vim.fn.getmousepos()
  local cfg = api.nvim_win_get_config(win)
  local chrome = 2 -- top + bottom border
  local top = vim.o.showtabline > 0 and 1 or 0
  local below = vim.o.lines - vim.o.cmdheight - 1 - mouse.screenrow - chrome
  local above = mouse.screenrow - 1 - top - chrome
  local height = api.nvim_win_get_height(win)
  local go_below = height <= below or below >= above
  api.nvim_win_set_config(win, {
    relative = "mouse",
    anchor = (go_below and "N" or "S") .. cfg.anchor:sub(2),
    row = go_below and 1 or 0,
    col = cfg.anchor:sub(2) == "W" and 0 or 1,
    height = math.max(1, math.min(height, go_below and below or above)),
  })
end

-- opts: { buf, win, row, col (0-based byte), mouse = bool, key }
local function show(opts)
  local buf, row, col = opts.buf, opts.row, opts.col
  local diags = diagnostics_at(buf, row, col)

  local function open(hover_lines)
    -- the pointer moved on while the server was answering
    if opts.mouse and state.key ~= opts.key then
      return
    end
    local lines, marks = render_diagnostics(diags)
    if #hover_lines > 0 then
      if #lines > 0 then
        lines[#lines + 1] = "---"
      end
      vim.list_extend(lines, hover_lines)
    end
    if #lines == 0 then
      return
    end

    if opts.mouse then
      close()
    end
    local fbuf, fwin = vim.lsp.util.open_floating_preview(lines, "markdown", {
      border = "rounded",
      max_width = math.min(100, math.floor(vim.o.columns * 0.6)),
      max_height = math.floor(vim.o.lines * 0.5),
      focus_id = FOCUS_ID,
      focus = not opts.mouse,
      relative = opts.mouse and "mouse" or nil,
    })
    -- second K: open_floating_preview focused the existing popup instead
    if fbuf == buf or not fwin or not api.nvim_win_is_valid(fwin) then
      return
    end
    for _, m in ipairs(marks) do
      pcall(api.nvim_buf_set_extmark, fbuf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
    end
    if opts.mouse then
      place_at_mouse(fwin)
      state.win, state.key, state.src_win = fwin, opts.key, opts.win
    end
  end

  local clients = vim.lsp.get_clients { bufnr = buf, method = "textDocument/hover" }
  if #clients == 0 then
    return open {}
  end

  local text = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  vim.lsp.buf_request_all(buf, "textDocument/hover", function(client)
    return {
      textDocument = vim.lsp.util.make_text_document_params(buf),
      position = { line = row, character = vim.str_utfindex(text, client.offset_encoding, col, false) },
    }
  end, function(results)
    local out = {}
    for _, res in pairs(results) do
      local contents = res.result and res.result.contents
      if contents then
        local md = vim.lsp.util.convert_input_to_markdown_lines(contents)
        if #md > 0 then
          if #out > 0 then
            out[#out + 1] = "---"
          end
          vim.list_extend(out, md)
        end
      end
    end
    open(out)
  end)
end

-- What the pointer is over: the word (or diagnostic) in an LSP buffer, as a key
-- that stays the same across the whole word. nil for anything else.
local function target(pos)
  local win = pos.winid
  if win == 0 or pos.line == 0 or api.nvim_win_get_config(win).relative ~= "" then
    return
  end
  local buf = api.nvim_win_get_buf(win)
  if #vim.lsp.get_clients { bufnr = buf } == 0 then
    return
  end
  local row, col = pos.line - 1, pos.column - 1
  local text = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  if col >= #text then
    return
  end

  local start = col
  if text:sub(col + 1, col + 1):match "[%w_]" then
    while start > 0 and text:sub(start, start):match "[%w_]" do
      start = start - 1
    end
  elseif #diagnostics_at(buf, row, col) == 0 then
    return -- whitespace / punctuation with nothing to report
  end
  return ("%d:%d:%d:%d"):format(win, buf, row, start), { buf = buf, win = win, row = row, col = col }
end

M.on_mouse_move = function()
  local pos = vim.fn.getmousepos()
  if state.win and pos.winid == state.win then
    timer:stop()
    return
  end
  local key, where = target(pos)
  if key == state.key then
    return
  end
  close()
  timer:stop()
  if not key then
    return
  end
  state.key = key -- pending: show() drops the answer if this changes meanwhile
  timer:start(
    DELAY,
    0,
    vim.schedule_wrap(function()
      if state.key == key and api.nvim_win_is_valid(where.win) then
        show(vim.tbl_extend("force", where, { mouse = true, key = key }))
      end
    end)
  )
end

M.at_cursor = function()
  local win = api.nvim_get_current_win()
  local cur = api.nvim_win_get_cursor(win)
  show { buf = api.nvim_get_current_buf(), win = win, row = cur[1] - 1, col = cur[2] }
end

M.setup = function()
  vim.o.mousemoveevent = true
  vim.keymap.set({ "n", "i" }, "<MouseMove>", M.on_mouse_move, { desc = "Hover under mouse" })
  vim.keymap.set("n", "K", M.at_cursor, { desc = "Hover: type, docs & diagnostics" })

  local group = api.nvim_create_augroup("HoverPopup", { clear = true })
  api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = function()
      if state.src_win and vim.v.event[tostring(state.src_win)] then
        close()
      end
    end,
  })
  api.nvim_create_autocmd({ "InsertCharPre", "FocusLost" }, {
    group = group,
    callback = function()
      if state.win then
        close()
      end
    end,
  })
end

return M
