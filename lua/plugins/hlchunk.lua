---@type LazySpec
return {
  "shellraining/hlchunk.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    require("hlchunk").setup {
      chunk = {
        enable = true,
        chars = {
          horizontal_line = "─",
          vertical_line = "│",
          left_top = "┌",
          left_bottom = "└",
          right_arrow = "─",
        },
        style = "#00ffff",
      },
      indent = {
        enable = true,
        chars = {
          "│",
        },
        style = {
          "#994444",
          "#994d22",
          "#999933",
          "#339933",
          "#339999",
          "#334499",
          "#663399",
        },
      },
      line_num = {
        enable = true,
        style = "#806d9c",
      },
    }
  end,
}
