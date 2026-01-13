return {
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      local dap_python = require "dap-python"
      dap_python.setup "python"

      -- Insert a new configuration with justMyCode = false
      table.insert(require("dap").configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch file (include libs)",
        program = "${file}",
        justMyCode = false, -- <—— here
        console = "integratedTerminal",
      })
    end,
  },
}
