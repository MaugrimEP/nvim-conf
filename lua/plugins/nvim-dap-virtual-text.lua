-- lua/plugins/nvim-dap-virtual-text.lua
return {
  {
    "theHamsta/nvim-dap-virtual-text",
    config = function()
      require("nvim-dap-virtual-text").setup {
        virt_text_pos = "eol",
        -- truncate long values
        display_callback = function(variable, buf, stackframe, node, options)
          -- strip newlines/spaces into one line
          local val = variable.value:gsub("%s+", " ")

          -- max length allowed
          local max_len = 200
          if #val > max_len then val = val:sub(1, max_len) .. "…" end

          if options.virt_text_pos == "inline" then
            return " = " .. val
          else
            return variable.name .. " = " .. val
          end
        end,
      }
    end,
  },
}
