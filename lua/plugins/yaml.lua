---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    config = {
      yamlls = {
        settings = {
          yaml = {
            schemaStore = {
              enable = true,
              url = "https://www.schemastore.org/api/json/catalog.json",
            },
            validate = true,
            hover = true,
            completion = true,
            format = {
              enable = false, -- formatting handled by prettier via none-ls
            },
          },
        },
      },
    },
  },
}
