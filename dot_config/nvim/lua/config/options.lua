vim.g.snacks_animate = false
vim.g.lazyvim_check_order = false

vim.opt.ignorecase = true

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.scrolloff = 8

-- Clipboard: headless devpod containers have no native provider (no X/Wayland,
-- so xclip/xsel/wl-copy can't work). Fall back to OSC 52 -- nvim hands yanks to
-- the local terminal (Ghostty) over the wire. Guarded so Mac (pbcopy) and
-- Windows (win32yank) keep their native providers untouched. Requires nvim 0.10+.
if vim.fn.has("mac") == 0 and vim.fn.has("win32") == 0
  and vim.fn.executable("xclip") == 0
  and vim.fn.executable("xsel") == 0
  and vim.fn.executable("wl-copy") == 0
then
  local osc52 = require("vim.ui.clipboard.osc52")
  -- Paste must NOT use osc52.paste: that's a clipboard READ query, terminals
  -- (WezTerm included) refuse those for security, and with LazyVim's
  -- clipboard=unnamedplus every plain `p` then hangs on "waiting for OSC 52
  -- response" (hit 2026-09-01 in the mercury devpod). Instead paste from
  -- nvim's own unnamed register: in-nvim yank/paste is instant, yanks still
  -- reach the system clipboard via OSC 52, and pasting FROM the host is the
  -- terminal's job (Ctrl+Shift+V / right-click).
  local function reg_paste()
    return { vim.split(vim.fn.getreg('"'), "
"), vim.fn.getregtype('"') }
  end
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = reg_paste, ["*"] = reg_paste },
  }
end
