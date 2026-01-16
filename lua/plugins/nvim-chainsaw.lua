return {
  "chrisgrieser/nvim-chainsaw",
  opts = {
    marker = "[Chainsaw]",
  }, -- required even if left empty

  config = function(_, opts)
    local chainsaw = require "chainsaw" -- don't eagerly load heavy modules if you want them lazy later

    -- ensure chainsaw is set up (plugin's setup)
    chainsaw.setup(opts)

    -- custom user commands
    vim.api.nvim_create_user_command(
      "ChainsawVar",
      function() chainsaw.variableLog() end,
      { desc = "Chainsaw: Log variable", nargs = 0 }
    )

    vim.api.nvim_create_user_command(
      "ChainsawObj",
      function() chainsaw.objectLog() end,
      { desc = "Chainsaw: Object log", nargs = 0 }
    )
  end,
}
