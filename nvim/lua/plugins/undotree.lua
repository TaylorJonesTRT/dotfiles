return {
  "mbbill/undotree",
  config = function()
    vim.keymap.set("n", "<leader>Ut", vim.cmd.UndotreeToggle)
  end,
}
