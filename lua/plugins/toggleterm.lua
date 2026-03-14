---@type LazySpec

-- Shared helper: update the winbar of any window showing this terminal
local function set_term_winbar(term)
  local name = term.display_name or ("Terminal " .. term.id)
  if term.bufnr then
    for _, win in ipairs(vim.fn.win_findbuf(term.bufnr)) do
      vim.wo[win].winbar = string.format(" [%d] %s", term.id, name)
    end
  end
end

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  opts = {
    shell = "/bin/bash --login",
    direction = "vertical",
    size = function(term)
      if term.direction == "vertical" then return math.floor(vim.o.columns * 0.4) end
      return 10
    end,
    open_mapping = [[<C-\>]], -- <count><C-\> toggles terminal by number
    on_open = function(term)
      set_term_winbar(term)
      vim.wo.number = false
      vim.wo.relativenumber = false
    end,
  },
  keys = {
    { "<F7>", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal (vertical)" },
    { "<Leader>t1", "<cmd>1ToggleTerm<cr>", desc = "Toggle terminal [1-9]" },
    { "<Leader>t2", "<cmd>2ToggleTerm<cr>", desc = "which_key_ignore" },
    { "<Leader>t3", "<cmd>3ToggleTerm<cr>", desc = "which_key_ignore" },
    { "<Leader>t4", "<cmd>4ToggleTerm<cr>", desc = "which_key_ignore" },
    { "<Leader>t5", "<cmd>5ToggleTerm<cr>", desc = "which_key_ignore" },
    { "<Leader>t6", "<cmd>6ToggleTerm<cr>", desc = "which_key_ignore" },
    { "<Leader>t7", "<cmd>7ToggleTerm<cr>", desc = "which_key_ignore" },
    { "<Leader>t8", "<cmd>8ToggleTerm<cr>", desc = "which_key_ignore" },
    { "<Leader>t9", "<cmd>9ToggleTerm<cr>", desc = "which_key_ignore" },
    {
      "<Leader>ft",
      function()
        local terms = require("toggleterm.terminal").get_all(true)
        if vim.tbl_isempty(terms) then
          vim.notify("No terminals open", vim.log.levels.INFO)
          return
        end

        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        pickers
          .new({}, {
            prompt_title = "Terminals  [<C-r> rename]",
            finder = finders.new_table({
              results = terms,
              entry_maker = function(term)
                local name = term.display_name or ("Terminal " .. term.id)
                local display = string.format("[%d] %s", term.id, name)
                return {
                  value = term,
                  display = display,
                  ordinal = display,
                }
              end,
            }),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr, map)
              actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local sel = action_state.get_selected_entry()
                if sel then sel.value:toggle() end
              end)

              local rename = function()
                local sel = action_state.get_selected_entry()
                if not sel then return end
                local term = sel.value
                actions.close(prompt_bufnr)
                vim.schedule(function()
                  local current = term.display_name or ("Terminal " .. term.id)
                  local new_name = vim.fn.input("Rename terminal: ", current)
                  if new_name ~= "" and new_name ~= current then
                    term.display_name = new_name
                    set_term_winbar(term)
                    vim.notify(("Terminal %d renamed to '%s'"):format(term.id, new_name), vim.log.levels.INFO)
                  end
                end)
              end

              map("i", "<C-r>", rename)
              map("n", "<C-r>", rename)
              return true
            end,
          })
          :find()
      end,
      desc = "Find terminal",
    },
  },
  config = function(_, opts)
    require("toggleterm").setup(opts)

    local Terminal = require("toggleterm.terminal").Terminal

    -- :TermNew [name] — create a new terminal with an optional display name
    vim.api.nvim_create_user_command("TermNew", function(args)
      local name = args.args ~= "" and args.args or nil
      local term = Terminal:new({ display_name = name })
      term:toggle()
    end, { nargs = "?", desc = "Create new terminal (with optional name)" })

    -- :TermRename <name> — rename the terminal in the current buffer
    vim.api.nvim_create_user_command("TermRename", function(args)
      local terms = require("toggleterm.terminal").get_all(true)
      local current_buf = vim.api.nvim_get_current_buf()
      for _, term in ipairs(terms) do
        if term.bufnr == current_buf then
          term.display_name = args.args
          set_term_winbar(term)
          vim.notify(("Terminal %d renamed to '%s'"):format(term.id, args.args), vim.log.levels.INFO)
          return
        end
      end
      vim.notify("Not in a terminal buffer", vim.log.levels.WARN)
    end, { nargs = 1, desc = "Rename current terminal" })
  end,
}
