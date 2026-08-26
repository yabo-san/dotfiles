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
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
end
