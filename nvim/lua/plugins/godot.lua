-- Godot / GDScript support. See docs/godotNeovimSetup.md

vim.api.nvim_create_autocmd("FileType", {
  pattern = "gdscript",
  callback = function(ev)
    vim.api.nvim_buf_create_user_command(ev.buf, "GodotBreakpoint", function()
      vim.cmd("normal! obreakpoint")
      vim.cmd("write")
    end, {})
    vim.api.nvim_buf_create_user_command(ev.buf, "GodotDeleteBreakpoints", function()
      vim.cmd([[g/^\s*breakpoint\s*$/d]])
    end, {})
    vim.api.nvim_buf_create_user_command(ev.buf, "GodotFindBreakpoints", function()
      vim.cmd([[silent grep! -w breakpoint | copen]])
    end, {})
  end,
})

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Godot editor is the server (TCP 6005); nothing to install
        gdscript = { mason = false },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "gdscript", "godot_resource", "gdshader" } },
  },
  {
    -- Godot editor's built-in debug adapter (Editor Settings > Network > Debug Adapter)
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")
      dap.adapters.godot = {
        type = "server",
        host = "127.0.0.1",
        port = tonumber(os.getenv("GDScript_DAP_Port") or "6006"),
      }
      local project = require("config.godot").root or "${workspaceFolder}"
      dap.configurations.gdscript = {
        { type = "godot", request = "launch", name = "Godot: Launch main scene", project = project },
        {
          type = "godot",
          request = "launch",
          name = "Godot: Launch current scene",
          project = project,
          launch_scene = true,
        },
      }
    end,
  },
}
