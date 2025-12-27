-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { noremap = true, silent = true })
vim.keymap.set("n", "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", { noremap = true, silent = true })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
