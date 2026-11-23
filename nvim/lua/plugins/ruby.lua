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
        -- Only attach in projects that use Sorbet (have sorbet/config)
        sorbet = {
          mason = false,
          cmd = { "bundle", "exec", "srb", "tc", "--lsp" },
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, { "Gemfile" })
            if root and vim.uv.fs_stat(root .. "/sorbet/config") then
              on_dir(root)
            end
          end,
        },
      },
    },
  },
}
