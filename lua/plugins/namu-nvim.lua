return {
  "bassamsdata/namu.nvim",

  opts = {
    global = {},
    namu_symbols = { -- Specific Module options
      options = {},
    },
  },

  -- === Suggested Keymaps: ===
  vim.keymap.set("n", "<leader>ss", ":Namu symbols<cr>", {
    desc = "Jump to LSP symbol",
    silent = true,
  }),
  vim.keymap.set("n", "<leader>sw", ":Namu workspace<cr>", {
    desc = "LSP Symbols - Workspace",
    silent = true,
  }),

  config = function(_, opts)
    local namu = require "namu" -- don't eagerly load heavy modules if you want them lazy later
  end,
}
