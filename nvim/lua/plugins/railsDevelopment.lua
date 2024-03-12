return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_ls = {
          cmd = { "bundle", "exec", "ruby-lsp" },
          init_options = {
            formatter = "auto",
          },
          settings = {},
        },
      },
    },
  },
}
