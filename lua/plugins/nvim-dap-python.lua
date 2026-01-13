return {
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      local dap_python = require "dap-python"
      dap_python.setup "python"

      table.insert(require("dap").configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch file (without libs, PYTHONPATH=.)",
        program = "${file}",
        justMyCode = false,
        console = "integratedTerminal",
        redirectOutput = true,
        cwd = "${workspaceFolder}",
        env = {
          PYTHONPATH = ".",
        },
      })
      table.insert(require("dap").configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch file (include libs)",
        program = "${file}",
        justMyCode = false,
        console = "integratedTerminal",
        redirectOutput = true,
        cwd = "${workspaceFolder}",
        env = {
          PYTHONPATH = ".",
        },
      })
    end,
  },
}
