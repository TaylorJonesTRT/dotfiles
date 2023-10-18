return {
  "nvim-telescope/telescope.nvim",

  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },

  config = function()
    local telescope = require("telescope")
    local builtin = require("telescope.builtin")

    telescope.setup({
      defaults = {
        layout_strategy = "vertical",
        layout_config = nil,
      },
      extension = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          case_mode = "smart_case",
        },
        repo = {
          search_dirs = {
            "~/Development/projects",
            "~/Development/",
          },
        },
      },
      pickers = {
        live_grep = {
          -- layout_strategy = "vertical",
          layout_config = {
            width = 0.9,
            height = 0.9,
            preview_cutoff = 1,
            mirror = false,
          },
        },
        lsp_implementations = {
          -- layout_strategy = "vertical",
          layout_config = {
            width = 0.9,
            height = 0.9,
            preview_cutoff = 1,
            mirror = false,
          },
        },
      },
    })

    -- See `:help telescope.builtin`
    vim.keymap.set("n", "<Leader>ff", builtin.find_files)
    vim.keymap.set("n", "<C-p>", builtin.git_files, {})
    vim.keymap.set("n", "<leader>ps", function()
      builtin.live_grep({ search = vim.fn.input("Grep> ") })
    end)
  end,
}
