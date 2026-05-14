local get_intelephense_licence = function()
  local f = assert(io.open(os.getenv("HOME") .. "/intelephense/licence.txt", "rb"))
  local content = f:read("*a")
  f:close()
  return string.gsub(content, "%s+", "")
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        phpcs = {
          mason = false,
        },
        intelephense = {
          init_options = {
            licenceKey = get_intelephense_licence(),
          },
          settings = {
            intelephense = {
              format = {
                enable = false,
              },
            },
            diagnostics = {
              enable = true,
              typeErrors = false,
            },
          },
        },
      },
      setup = {
        intelephense = function(_, opts)
          local lspconfig = require("lspconfig")
          local util = require("lspconfig.util")

          opts.root_dir = function(fname)
            local xenforo_root = util.root_pattern("src/XF/App.php")(fname)
            if xenforo_root then
              return xenforo_root
            end

            return util.root_pattern("composer.json", ".git", "index.php")(fname) or util.path.dirname(fname)
          end

          lspconfig.intelephense.setup(opts)
          return true
        end,
      },
    },
  },

  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        php = { "php_cs_fixer" },
      },
      formatters = {
        php_cs_fixer = {
          command = "vendor/bin/php-cs-fixer",
          args = {
            "fix",
            "$FILENAME",
          },
          stdin = false,
          cwd = require("conform.util").root_file({
            ".php-cs-fixer.dist.php",
            ".php-cs-fixer.php",
            "src/XF/App.php",
          }),
        },
      },
    },
  },
}
