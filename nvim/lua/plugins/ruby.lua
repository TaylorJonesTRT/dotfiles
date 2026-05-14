return {
  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "RRethy/nvim-treesitter-endwise",
    },
    opts = function(_, opts)
      opts.endwise = { enable = true }
      return opts
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_lsp = {
          mason = false,
          cmd = { "ruby-lsp" },
          cmd_env = {
            RAILS_ENV = "development",
          },
        },
      },
    },
  },
}
