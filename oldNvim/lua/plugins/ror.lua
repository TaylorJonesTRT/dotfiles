return {
  "weizheheng/ror.nvim",
  config = function()
    local ror = require('ror')

    ror.setup({
      vim.keymap.set("n", "<Leader>ror", ":lua require('ror.commands').list_commands()<CR>", { silent = true })
    })
  end
}
