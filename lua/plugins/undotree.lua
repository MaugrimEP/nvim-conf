return {
    "mbbill/undotree",
  {
    lazy = false,               -- load it at startup
    config = function()
      require("undotree").setup({
        float_diff = true,
        layout = "left_bottom",
        ignore_filetype = { "Undotree", "UndotreeDiff", "qf", "TelescopePrompt" },
        -- window = { winblend = 30 },
        -- keymaps = {
        --   j = "move_next",
        --   k = "move_prev",
        --   J = "move_change_next",
        --   K = "move_change_prev",
        -- },
      })
    end,
  },
}

