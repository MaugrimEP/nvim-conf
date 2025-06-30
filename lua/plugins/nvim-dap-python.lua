return {
  {
    "mfussenegger/nvim-dap-python",
    config = function(_, opts) require("dap-python").setup "python" end,
  },
}
