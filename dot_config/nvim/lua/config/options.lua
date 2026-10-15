vim.g.snacks_animate = false
vim.g.lazyvim_check_order = false

vim.opt.ignorecase = true

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.scrolloff = 8

-- Clipboard: headless devpod containers have no provider, so fall back to OSC 52 (nvim 0.10+).
-- Mac and Windows keep their native providers.
if vim.fn.has("mac") == 0 and vim.fn.has("win32") == 0
  and vim.fn.executable("xclip") == 0
  and vim.fn.executable("xsel") == 0
  and vim.fn.executable("wl-copy") == 0
then
  local osc52 = require("vim.ui.clipboard.osc52")
  -- Not osc52.paste: terminals refuse clipboard READ queries, so every `p` hung (2026-09-01).
  -- Paste from nvim's own register; pasting from the host is the terminal's job.
  local function reg_paste()
    return { vim.split(vim.fn.getreg('"'), "\n"), vim.fn.getregtype('"') }
  end
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = reg_paste, ["*"] = reg_paste },
  }
end
