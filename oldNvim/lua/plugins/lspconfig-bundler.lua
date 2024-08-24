return {
  "mihyaeru21/nvim-lspconfig-bundler",
  event = "BufReadPre",
  dependencies = {
    "neovim/nvim-lspconfig",
  },
  config = function()
    require("lspconfig-bundler").setup()
  end,
}
