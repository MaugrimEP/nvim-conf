-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

-- Run the builtin `gf` (works in both Normal and Visual mode); if it can't
-- resolve the file, fall back to a fuzzy Telescope search seeded with the
-- basename of whatever it was looking at.
local function gf_with_fuzzy(visual)
  -- capture the target first so we can seed the fuzzy fallback with it
  local target
  if visual then
    -- getregion works while still in Visual mode (marks aren't set yet)
    local region = vim.fn.getregion(vim.fn.getpos "v", vim.fn.getpos ".", { type = vim.fn.mode() })
    target = table.concat(region, "")
  else
    target = vim.fn.expand "<cfile>"
  end

  if pcall(vim.cmd, "normal! gf") then return end -- builtin gf succeeded

  target = vim.trim(target)
  if target == "" then return end
  require("telescope.builtin").find_files { default_text = vim.fn.fnamemodify(target, ":t") }
end

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Configure core features of AstroNvim
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = true, -- enable autopairs at start
      cmp = true, -- enable completion at start
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
      signs = false,
    },
    -- passed to `vim.filetype.add`
    filetypes = {
      -- see `:h vim.filetype.add` for usage
      extension = {
        foo = "fooscript",
      },
      filename = {
        [".foorc"] = "fooscript",
      },
      pattern = {
        [".*/etc/foo/.*"] = "fooscript",
      },
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        relativenumber = true, -- sets vim.opt.relativenumber
        number = true, -- sets vim.opt.number
        spell = false, -- sets vim.opt.spell
        signcolumn = "yes:2", -- sets vim.opt.signcolumn to yes (2 columns for gitsigns + todo-comments)
        wrap = true, -- sets vim.opt.wrap
        mouse = "nv", -- exclude insert mode so terminal handles right-click paste
        lazyredraw = true,
      },
      g = { -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
        matchup_matchparen_offscreen = { method = "popup" }, -- show offscreen match in a popup instead of the statusline
      },
    },
    -- Mappings can be configured through AstroCore as well.
    -- NOTE: keycodes follow the casing in the vimdocs. For example, `<Leader>` must be capitalized
    mappings = {
      -- first key is the mode
      i = {
        ["jk"] = { "<Esc>", desc = "Exit insert mode" },
      },
      n = {
        -- second key is the lefthand side of the map

        -- navigate buffer tabs
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- mappings seen under group name "Buffer"
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },

        -- tables with just a `desc` key will be registered with which-key if it's installed
        -- this is useful for naming menus
        -- ["<Leader>b"] = { desc = "Buffers" },

        -- live grep with telescope
        ["<Leader>fg"] = { function() require("telescope.builtin").live_grep() end, desc = "Find words (live grep)" },

        -- goto file under cursor, fall back to fuzzy find if not resolvable
        ["gf"] = {
          function() gf_with_fuzzy(false) end,
          desc = "Goto file (fuzzy fallback)",
        },

        -- toggle mouse mode
        ["<Leader>um"] = {
          function()
            if vim.o.mouse == "" then
              vim.opt.mouse = "nv"
              vim.notify("Mouse enabled", vim.log.levels.INFO)
            else
              vim.opt.mouse = ""
              vim.notify("Mouse disabled", vim.log.levels.INFO)
            end
          end,
          desc = "Toggle mouse",
        },

        -- terminal group label (which-key)
        ["<Leader>t"] = { desc = "Terminal" },

        -- setting a mapping to false will disable it
        -- ["<C-S>"] = false,
      },
      x = {
        -- open the visual selection as a file, fall back to fuzzy find
        ["gf"] = {
          function() gf_with_fuzzy(true) end,
          desc = "Goto file from selection (fuzzy fallback)",
        },
      },
      t = {
        -- Disable <C-h> window navigation in terminal mode so backspace works
        -- (many terminals send <C-h> for backspace, which conflicts with window nav in splits)
        ["<C-h>"] = false,
        -- Exit terminal mode with Escape so you can use normal window navigation (<C-w>h/j/k/l)
        ["<Esc>"] = { "<C-\\><C-n>", desc = "Exit terminal mode" },
      },
    },
  },
}
