return {
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      local dap = require "dap"
      local dap_python = require "dap-python"
      dap_python.setup "python"

      -- Configure external terminal (used when console = "externalTerminal")
      -- Priority: $TERMINAL env var → x-terminal-emulator → known list
      local function detect_external_terminal()
        local env_term = vim.env.TERMINAL
        if env_term and vim.fn.executable(env_term) == 1 then
          return { command = env_term, args = { "-e" } }
        end
        for _, t in ipairs {
          { cmd = "x-terminal-emulator", args = { "-e" } },
          { cmd = "kitty",               args = {} },
          { cmd = "alacritty",           args = { "-e" } },
          { cmd = "wezterm",             args = { "start", "--" } },
          { cmd = "foot",                args = { "-e" } },
          { cmd = "xterm",               args = { "-e" } },
          { cmd = "gnome-terminal",      args = { "--" } },
          { cmd = "konsole",             args = { "-e" } },
        } do
          if vim.fn.executable(t.cmd) == 1 then return { command = t.cmd, args = t.args } end
        end
      end
      local ext_term = detect_external_terminal()
      if ext_term then dap.defaults.fallback.external_terminal = ext_term end

      -- Basic config registered for :DapContinue
      table.insert(dap.configurations.python, {
        type = "python",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        justMyCode = false,
        console = "integratedTerminal",
        redirectOutput = true,
        cwd = "${workspaceFolder}",
        env = { PYTHONPATH = "." },
      })

      -- ── History ──────────────────────────────────────────────────────────

      local HISTORY_FILE = vim.fn.stdpath "data" .. "/dap_python_history.json"
      local HISTORY_MAX  = 10

      local function load_history()
        local ok, data = pcall(vim.fn.readfile, HISTORY_FILE)
        if not ok or #data == 0 then return {} end
        local decoded = vim.json.decode(table.concat(data, ""))
        return type(decoded) == "table" and decoded or {}
      end

      local function save_history(sel)
        local history = load_history()
        local encoded = vim.json.encode(sel)

        -- Remove duplicate if it exists
        for i, entry in ipairs(history) do
          if vim.json.encode(entry) == encoded then
            table.remove(history, i)
            break
          end
        end

        -- Prepend and cap
        table.insert(history, 1, sel)
        if #history > HISTORY_MAX then history[#history] = nil end

        pcall(vim.fn.writefile, { vim.json.encode(history) }, HISTORY_FILE)
      end

      -- ── Runner ───────────────────────────────────────────────────────────

      local function find_adapter_python(runtime_python)
        vim.fn.system { runtime_python, "-c", "import debugpy" }
        if vim.v.shell_error == 0 then return runtime_python end

        local mason = vim.fn.stdpath "data" .. "/mason/packages/debugpy/venv/bin/python"
        if vim.fn.executable(mason) == 1 then return mason end

        local dedicated = vim.fn.expand "~/.virtualenvs/debugpy/bin/python"
        if vim.fn.executable(dedicated) == 1 then return dedicated end

        local uv_tool = vim.fn.expand "~/.local/share/uv/tools/debugpy/bin/python"
        if vim.fn.executable(uv_tool) == 1 then return uv_tool end

        return nil
      end

      local function run_from_sel(sel)
        local config_name = (sel.name and sel.name ~= "(none)" and sel.name ~= "") and sel.name or nil

        if sel.mode == "attach" then
          dap.run {
            type       = "python",
            request    = "attach",
            name       = config_name or "Attach",
            justMyCode = sel.justMyCode == "true",
            connect    = { host = sel.host, port = tonumber(sel.port) },
          }
          save_history(sel)
          return
        end

        local cwd = vim.fn.getcwd()
        local python_path

        if sel.runner == "uv" then
          local handle = io.popen "uv python find 2>/dev/null"
          if handle then
            local result = handle:read "*l"
            handle:close()
            python_path = (result and result ~= "") and result or "python"
          else
            python_path = "python"
          end
        elseif sel.interpreter == "system" then
          python_path = "python"
        elseif sel.interpreter == "$VIRTUAL_ENV" then
          python_path = vim.env.VIRTUAL_ENV .. "/bin/python"
        else
          python_path = cwd .. "/" .. sel.interpreter .. "/bin/python"
        end

        local adapter_python = find_adapter_python(python_path)
        if not adapter_python then
          vim.notify(
            "debugpy not found. Install with:\n  uv add --dev debugpy\n  or: uv tool install debugpy",
            vim.log.levels.ERROR
          )
          return
        end

        if sel.flake == "true" then
          -- Redirect stdout→stderr during nix shell hook phase, then restore for debugpy.
          -- Without this, hooks like venvShellHook pollute the DAP stdout stream.
          dap.adapters.python = {
            type    = "executable",
            command = "bash",
            args    = {
              "-c",
              string.format(
                "exec 3>&1 1>&2; nix develop --command sh -c 'exec 1>&3 3>&-; exec \"%s\" -m debugpy.adapter'",
                adapter_python
              ),
            },
          }
        else
          dap.adapters.python = {
            type    = "executable",
            command = adapter_python,
            args    = { "-m", "debugpy.adapter" },
          }
        end

        local env = sel.PYTHONPATH ~= "(none)" and { PYTHONPATH = sel.PYTHONPATH } or nil

        local args = nil
        if sel.args ~= "(none)" and sel.args ~= "" then
          if sel.args:sub(1, 1) == "@" then
            local filepath = vim.fn.expand(sel.args:sub(2))
            local ok, lines = pcall(vim.fn.readfile, filepath)
            if ok then
              args = vim.split(table.concat(lines, " "), "%s+", { trimempty = true })
            else
              vim.notify("Could not read args file: " .. filepath, vim.log.levels.WARN)
            end
          else
            args = vim.split(sel.args, "%s+", { trimempty = true })
          end
        end

        dap.run {
          type           = "python",
          request        = "launch",
          name           = config_name or "Custom launch",
          program        = "${file}",
          justMyCode     = sel.justMyCode == "true",
          console        = sel.console,
          redirectOutput = true,
          cwd            = "${workspaceFolder}",
          pythonPath     = python_path,
          env            = env,
          args           = args,
        }
        save_history(sel)
      end

      -- ── History picker (<leader>dh) ───────────────────────────────────────

      local function format_sel(sel)
        local name   = (sel.name and sel.name ~= "(none)" and sel.name ~= "") and ("[" .. sel.name .. "] ") or ""
        if sel.mode == "attach" then
          return string.format("%s[attach] %s:%s  justMyCode:%s", name, sel.host, sel.port, sel.justMyCode)
        end
        local parts = { string.format("%s[launch] %s", name, sel.interpreter) }
        if sel.runner == "uv" then table.insert(parts, "uv") end
        if sel.justMyCode == "true" then table.insert(parts, "justMyCode") end
        if sel.flake == "true" then table.insert(parts, "flake") end
        if sel.args ~= "(none)" then table.insert(parts, "args:" .. sel.args) end
        if sel.PYTHONPATH ~= "(none)" then table.insert(parts, "PYTHONPATH:" .. sel.PYTHONPATH) end
        return table.concat(parts, "  ")
      end

      local function open_history_picker()
        local history = load_history()
        if #history == 0 then
          vim.notify("No debug history yet", vim.log.levels.INFO)
          return
        end

        local pickers      = require "telescope.pickers"
        local finders      = require "telescope.finders"
        local conf         = require("telescope.config").values
        local actions      = require "telescope.actions"
        local action_state = require "telescope.actions.state"

        pickers.new({}, {
          prompt_title = "Python Debug History",
          finder = finders.new_table {
            results = history,
            entry_maker = function(sel)
              local display = format_sel(sel)
              return { value = sel, display = display, ordinal = display }
            end,
          },
          sorter = conf.generic_sorter {},
          attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              run_from_sel(action_state.get_selected_entry().value)
            end)
            return true
          end,
        }):find()
      end

      -- ── Form (<leader>dP) ─────────────────────────────────────────────────

      local function open_dap_form()
        local Popup = require "nui.popup"

        local function detect_venvs()
          local opts = {}
          local cwd = vim.fn.getcwd()
          for _, name in ipairs { ".venv", "venv", ".env", "env" } do
            if vim.fn.executable(cwd .. "/" .. name .. "/bin/python") == 1 then table.insert(opts, name) end
          end
          if vim.env.VIRTUAL_ENV then table.insert(opts, "$VIRTUAL_ENV") end
          table.insert(opts, "system")
          return opts
        end

        -- value holds the current effective value (custom override or preset from options)
        local fields = {
          { label = "name",        options = { "(none)" },                                                    idx = 1 },
          { label = "mode",        options = { "launch", "attach" },                                          idx = 1 },
          { label = "flake",       options = { "false", "true" },                                             idx = 1 },
          { label = "runner",      options = { "direct", "uv" },                                              idx = 1 },
          { label = "justMyCode",  options = { "true", "false" },                                             idx = 1 },
          { label = "console",     options = { "integratedTerminal", "externalTerminal", "internalConsole" }, idx = 1 },
          { label = "interpreter", options = detect_venvs(),                                                  idx = 1 },
          { label = "PYTHONPATH",  options = { ".", "(none)" },                                               idx = 1 },
          { label = "args",        options = { "(none)" },                                                    idx = 1 },
          { label = "host",        options = { "127.0.0.1", "0.0.0.0" },                                     idx = 1 },
          { label = "port",        options = { "5678", "5679", "5680" },                                      idx = 1 },
        }

        local LABEL_W = 14
        local INDENT  = 2
        local SEP     = 2
        local width   = 58
        local height = #fields + 9

        local popup = Popup {
          position = "50%",
          size     = { width = width, height = height },
          border   = {
            style = "rounded",
            text  = { top = " Python Debug Config ", top_align = "center" },
          },
          win_options = {
            cursorline     = true,
            number         = false,
            relativenumber = false,
            signcolumn     = "no",
          },
        }

        popup:mount()
        vim.api.nvim_set_current_win(popup.winid)

        local ns = vim.api.nvim_create_namespace "dap_form_hl"

        local function field_value(f) return f.value or f.options[f.idx] end

        local function render()
          local mode = field_value(fields[1])
          local lines = { "" }
          for _, f in ipairs(fields) do
            lines[#lines + 1] = string.format(
              string.rep(" ", INDENT) .. "%-" .. LABEL_W .. "s" .. string.rep(" ", SEP) .. "[%s]",
              f.label,
              field_value(f)
            )
          end
          lines[#lines + 1] = ""
          lines[#lines + 1] = string.rep(" ", INDENT) .. "h/l: cycle  i: type value  f: pick args file"
          lines[#lines + 1] = string.rep(" ", INDENT) .. "j/k: navigate field    <CR>: run    q: close"

          -- Attach help (always 4 lines to keep popup height stable)
          -- hint_start is the 0-indexed line of the title (blank separator comes just before it)
          local hint_start = #lines + 1
          if mode == "attach" then
            local host, port = "127.0.0.1", "5678"
            for _, f in ipairs(fields) do
              if f.label == "host" then host = field_value(f) end
              if f.label == "port" then port = field_value(f) end
            end
            lines[#lines + 1] = ""
            lines[#lines + 1] = string.rep(" ", INDENT) .. "Start your script with:"
            lines[#lines + 1] = string.rep(" ", INDENT) .. "python -m debugpy --listen " .. host .. ":" .. port
            lines[#lines + 1] = string.rep(" ", INDENT + 2) .. "--wait-for-client your_script.py"
          else
            lines[#lines + 1] = ""
            lines[#lines + 1] = ""
            lines[#lines + 1] = ""
            lines[#lines + 1] = ""
          end

          vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", true)
          vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
          vim.api.nvim_buf_set_option(popup.bufnr, "modifiable", false)

          -- Highlight values; dim fields irrelevant to current mode
          vim.api.nvim_buf_clear_namespace(popup.bufnr, ns, 0, -1)
          local val_col     = INDENT + LABEL_W + SEP + 1
          local launch_only = { runner = true, interpreter = true, PYTHONPATH = true, args = true, console = true, flake = true }
          local attach_only = { host = true, port = true }
          for i, f in ipairs(fields) do
            local dimmed = (mode == "attach" and launch_only[f.label])
                        or (mode == "launch" and attach_only[f.label])
            local val = field_value(f)
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, dimmed and "Comment" or "DiagnosticInfo", i, val_col, val_col + #val)
          end

          if mode == "attach" then
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, "DiagnosticHint", hint_start,     0, -1)
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, "DiagnosticInfo", hint_start + 1, 0, -1)
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, "DiagnosticInfo", hint_start + 2, 0, -1)
          end
        end

        render()
        vim.api.nvim_win_set_cursor(popup.winid, { 2, 0 })

        local function get_field()
          local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
          return fields[row - 1]
        end

        local function clamp_cursor()
          local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
          vim.api.nvim_win_set_cursor(popup.winid, { math.max(2, math.min(#fields + 1, row)), 0 })
        end

        popup:map("n", "j", function()
          local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
          if row < #fields + 1 then vim.api.nvim_win_set_cursor(popup.winid, { row + 1, 0 }) end
        end)

        popup:map("n", "k", function()
          local row = vim.api.nvim_win_get_cursor(popup.winid)[1]
          if row > 2 then vim.api.nvim_win_set_cursor(popup.winid, { row - 1, 0 }) end
        end)

        popup:map("n", "l", function()
          clamp_cursor()
          local f = get_field()
          if f then
            f.idx   = (f.idx % #f.options) + 1
            f.value = nil
            render()
          end
        end)

        popup:map("n", "h", function()
          clamp_cursor()
          local f = get_field()
          if f then
            f.idx   = ((f.idx - 2) % #f.options) + 1
            f.value = nil
            render()
          end
        end)

        popup:map("n", "f", function()
          clamp_cursor()
          local f = get_field()
          if not f or f.label ~= "args" then return end
          vim.schedule(function()
            local filepath = vim.fn.input { prompt = "Args file: ", default = "", completion = "file" }
            if filepath and filepath ~= "" then
              f.value = "@" .. vim.fn.fnamemodify(vim.fn.expand(filepath), ":~:.")
              render()
            end
            vim.api.nvim_set_current_win(popup.winid)
          end)
        end)

        popup:map("n", "i", function()
          clamp_cursor()
          local f = get_field()
          if not f then return end
          vim.schedule(function()
            local val = vim.fn.input { prompt = f.label .. ": ", default = field_value(f) }
            if val and val ~= "" then
              f.value = val
              render()
            end
            vim.api.nvim_set_current_win(popup.winid)
          end)
        end)

        popup:map("n", "<CR>", function()
          local sel = {}
          for _, f in ipairs(fields) do
            sel[f.label] = field_value(f)
          end
          popup:unmount()
          run_from_sel(sel)
        end)

        popup:map("n", "q",     function() popup:unmount() end)
        popup:map("n", "<Esc>", function() popup:unmount() end)
      end

      vim.keymap.set("n", "<leader>dP", open_dap_form,        { desc = "Python debug config form" })
      vim.keymap.set("n", "<leader>dh", open_history_picker,  { desc = "Python debug history" })
    end,
  },
}
