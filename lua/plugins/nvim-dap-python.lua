return {
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      local dap = require "dap"
      local dap_python = require "dap-python"
      dap_python.setup "python"

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

      -- Find a python that has debugpy installed, for the adapter
      local function find_adapter_python(runtime_python)
        -- 1. runtime python itself has debugpy (e.g. after `uv add --dev debugpy`)
        vim.fn.system { runtime_python, "-c", "import debugpy" }
        if vim.v.shell_error == 0 then return runtime_python end

        -- 2. Mason-installed debugpy
        local mason = vim.fn.stdpath "data" .. "/mason/packages/debugpy/venv/bin/python"
        if vim.fn.executable(mason) == 1 then return mason end

        -- 3. Dedicated debugpy venv (nvim-dap-python recommended)
        local dedicated = vim.fn.expand "~/.virtualenvs/debugpy/bin/python"
        if vim.fn.executable(dedicated) == 1 then return dedicated end

        -- 4. uv tool install debugpy
        local uv_tool = vim.fn.expand "~/.local/share/uv/tools/debugpy/bin/python"
        if vim.fn.executable(uv_tool) == 1 then return uv_tool end

        return nil
      end

      -- Form-based config builder (<leader>dP)
      local function open_dap_form()
        local Popup = require "nui.popup"

        local function detect_venvs()
          local opts = {}
          local cwd = vim.fn.getcwd()
          for _, name in ipairs { ".venv", "venv", ".env", "env" } do
            if vim.fn.executable(cwd .. "/" .. name .. "/bin/python") == 1 then
              table.insert(opts, name)
            end
          end
          if vim.env.VIRTUAL_ENV then table.insert(opts, "$VIRTUAL_ENV") end
          table.insert(opts, "system")
          return opts
        end

        -- editable=true fields support custom text input via "i"
        -- value holds the current effective value (custom or from options)
        local fields = {
          { label = "mode",        options = { "launch", "attach" },                                              idx = 1 },
          { label = "runner",      options = { "direct", "uv" },                                                  idx = 1 },
          { label = "justMyCode",  options = { "false", "true" },                                                 idx = 1 },
          { label = "console",     options = { "integratedTerminal", "externalTerminal", "internalConsole" },     idx = 1 },
          { label = "interpreter", options = detect_venvs(),                                                      idx = 1 },
          { label = "PYTHONPATH",  options = { ".", "(none)" },                                                   idx = 1 },
          { label = "args",        options = { "(none)" },                idx = 1, editable = true },
          { label = "host",        options = { "127.0.0.1", "0.0.0.0" }, idx = 1, editable = true },
          { label = "port",        options = { "5678", "5679", "5680" },  idx = 1, editable = true },
        }

        -- Layout constants
        local LABEL_W = 14
        local INDENT  = 2
        local SEP     = 2
        local width   = 58
        local height  = #fields + 9  -- blank + fields + blank + hint1 + hint2 + blank + help*3

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
              f.label, field_value(f)
            )
          end
          lines[#lines + 1] = ""
          lines[#lines + 1] = string.rep(" ", INDENT) .. "h/l: cycle  i: type value  f: pick args file"
          lines[#lines + 1] = string.rep(" ", INDENT) .. "j/k: navigate field    <CR>: run    q: close"

          -- Attach help section (always reserve 4 lines for stable popup height)
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
          local val_col = INDENT + LABEL_W + SEP + 1 -- +1 to skip "["
          local launch_only = { runner = true, interpreter = true, PYTHONPATH = true, args = true }
          local attach_only = { host = true, port = true }
          for i, f in ipairs(fields) do
            local dimmed = (mode == "attach" and launch_only[f.label])
                        or (mode == "launch" and attach_only[f.label])
            local hl = dimmed and "Comment" or "DiagnosticInfo"
            local val = field_value(f)
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, hl, i, val_col, val_col + #val)
          end

          -- Highlight attach help text
          if mode == "attach" then
            local title_line = hint_start      -- 0-indexed
            local cmd_line   = hint_start + 1
            local arg_line   = hint_start + 2
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, "DiagnosticHint",  title_line, 0, -1)
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, "DiagnosticInfo",  cmd_line,   0, -1)
            vim.api.nvim_buf_add_highlight(popup.bufnr, ns, "DiagnosticInfo",  arg_line,   0, -1)
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
            f.idx = (f.idx % #f.options) + 1
            f.value = nil -- clear custom value when cycling presets
            render()
          end
        end)

        popup:map("n", "h", function()
          clamp_cursor()
          local f = get_field()
          if f then
            f.idx = ((f.idx - 2) % #f.options) + 1
            f.value = nil
            render()
          end
        end)

        -- "f" to pick a file as args source (only on the args field)
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

        -- "i" to type a custom value for the current field
        popup:map("n", "i", function()
          clamp_cursor()
          local f = get_field()
          if not f then return end
          local current = field_value(f)
          -- schedule so the popup stays visible while input prompt appears
          vim.schedule(function()
            local val = vim.fn.input { prompt = f.label .. ": ", default = current }
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

          if sel.mode == "attach" then
            -- Attach to a running debugpy process
            dap.run {
              type         = "python",
              request      = "attach",
              name         = "Attach",
              justMyCode   = sel.justMyCode == "true",
              connect      = {
                host = sel.host,
                port = tonumber(sel.port),
              },
            }
            return
          end

          -- Launch mode: resolve python interpreter
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

          dap.adapters.python = {
            type    = "executable",
            command = adapter_python,
            args    = { "-m", "debugpy.adapter" },
          }

          local env = {}
          if sel.PYTHONPATH ~= "(none)" then env.PYTHONPATH = sel.PYTHONPATH end

          local args = nil
          if sel.args ~= "(none)" and sel.args ~= "" then
            if sel.args:sub(1, 1) == "@" then
              local filepath = vim.fn.expand(sel.args:sub(2))
              local ok, lines = pcall(vim.fn.readfile, filepath)
              if ok then
                local content = table.concat(lines, " ")
                args = vim.split(content, "%s+", { trimempty = true })
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
            name           = "Custom launch",
            program        = "${file}",
            justMyCode     = sel.justMyCode == "true",
            console        = sel.console,
            redirectOutput = true,
            cwd            = "${workspaceFolder}",
            pythonPath     = python_path,
            env            = env,
            args           = args,
          }
        end)

        popup:map("n", "q",     function() popup:unmount() end)
        popup:map("n", "<Esc>", function() popup:unmount() end)
      end

      vim.keymap.set("n", "<leader>dP", open_dap_form, { desc = "Python debug config form" })
    end,
  },
}
