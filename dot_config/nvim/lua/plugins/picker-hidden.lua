-- Show dotfiles in the snacks pickers and the explorer by default.
-- In GitOps and dotfiles repos the hidden files ARE the config: .sops.yaml,
-- .github/, .gitignore, .chezmoiignore. Found the hard way: .sops.yaml never
-- appeared in <leader>ff because hidden defaults to false.
-- Runtime toggles still work: <a-h> hidden, <a-i> ignored (H / I in the explorer).
-- .git/ stays out: snacks excludes it on its own.
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          files = { hidden = true },
          grep = { hidden = true },
          explorer = { hidden = true },
        },
      },
    },
  },
}
