return {
  {
    "Weissle/persistent-breakpoints.nvim",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("persistent-breakpoints").setup {
        save_dir = vim.fn.stdpath "data" .. "/nvim-persistent-breakpoints",
        load_breakpoints_event = { "BufReadPost" },
        perf_record = false,
      }

      local pb_api = require "persistent-breakpoints.api"
      vim.keymap.set("n", "<leader>db", pb_api.toggle_breakpoint,       { desc = "Toggle breakpoint (persistent)" })
      vim.keymap.set("n", "<leader>dB", pb_api.set_conditional_breakpoint, { desc = "Conditional breakpoint (persistent)" })
      vim.keymap.set("n", "<leader>dC", pb_api.clear_all_breakpoints,   { desc = "Clear all breakpoints (persistent)" })
    end,
  },
}
