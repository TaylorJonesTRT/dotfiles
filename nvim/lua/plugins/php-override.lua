return {
  -- Override LazyVim's Mason PHP tools - remove phpcs
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      -- Filter out phpcs from the list
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "phpcs"
      end, opts.ensure_installed)
    end,
  },

  -- Override LazyVim's nvim-lint PHP config - remove phpcs
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      -- Set PHP linters to empty table (no phpcs)
      opts.linters_by_ft.php = {}
    end,
  },
}
