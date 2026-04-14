-- Customize None-ls sources

---@type LazySpec
return {
  "nvimtools/none-ls.nvim",
  opts = function(_, opts)
    local null_ls = require "null-ls"

    -- Check supported formatters and linters
    -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/formatting
    -- https://github.com/nvimtools/none-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics

    -- Only insert new sources, do not replace the existing ones
    opts.sources = require("astrocore").list_insert_unique(opts.sources, {
      -- YAML linter
      null_ls.builtins.diagnostics.yamllint,
      -- YAML formatter (prettier handles yaml, json, etc.)
      null_ls.builtins.formatting.prettier.with {
        filetypes = { "yaml", "yml" },
      },
    })
  end,
}
