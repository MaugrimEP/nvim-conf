-- Customize Mason

-- Maps Mason package names to the binary to check on the system PATH.
-- If the binary is found, the package is skipped from Mason and registered
-- as a system server for astrolsp instead.
local prefer_system = {
  ["basedpyright"] = "basedpyright-langserver",
  ["ruff"] = "ruff",
  ["lua-language-server"] = "lua-language-server",
  ["stylua"] = "stylua",
  ["debugpy"] = "debugpy",
  ["tree-sitter-cli"] = "tree-sitter",
  ["yaml-language-server"] = "yaml-language-server",
  ["yamllint"] = "yamllint",
  ["prettier"] = "prettier",
}

local all_packages = {
  "basedpyright",
  "ruff",
  "lua-language-server",
  "stylua",
  "debugpy",
  "tree-sitter-cli",
  "yaml-language-server",
  "yamllint",
  "prettier",
}

local ensure_installed = {}
local system_servers = {}

for _, pkg in ipairs(all_packages) do
  local bin = prefer_system[pkg]
  if bin and vim.fn.executable(bin) == 1 then
    -- server is on the system, tell astrolsp to use it directly
    table.insert(system_servers, pkg)
  else
    -- not found on system, let Mason install it
    table.insert(ensure_installed, pkg)
  end
end

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = ensure_installed,
    },
  },
  {
    "AstroNvim/astrolsp",
    opts = {
      servers = system_servers,
    },
  },
}
