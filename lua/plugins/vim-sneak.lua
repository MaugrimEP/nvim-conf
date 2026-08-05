---@type LazySpec
return {
  "justinmk/vim-sneak",
  event = "VeryLazy",
  init = function() vim.g["sneak#label"] = 1 end,
  config = function()
    -- Sneak only auto-maps a key when nothing else maps it, which loses races we
    -- can't win: the snacks dashboard takes `s` when nvim starts without a file,
    -- and vim-matchup takes `z` in operator-pending. Map the <Plug> keys directly.
    local map = function(mode, lhs, plug, desc) vim.keymap.set(mode, lhs, plug, { remap = true, desc = desc }) end

    map("n", "s", "<Plug>Sneak_s", "Sneak forward")
    map("n", "S", "<Plug>Sneak_S", "Sneak backward")

    -- `S` stays free in visual mode for nvim-surround, so backward is `Z`
    map("x", "s", "<Plug>Sneak_s", "Sneak forward")
    map("x", "Z", "<Plug>Sneak_S", "Sneak backward")

    map("o", "z", "<Plug>Sneak_s", "Sneak forward")
    map("o", "Z", "<Plug>Sneak_S", "Sneak backward")
  end,
}
