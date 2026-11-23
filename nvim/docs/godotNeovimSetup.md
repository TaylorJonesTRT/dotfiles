# Plan: Neovim as Godot's external editor (per simondalvai.org/blog/godot-neovim)

## Context
You want Godot to open scripts in Neovim, with GDScript LSP, treesitter highlighting, breakpoint helpers, and Godot clutter hidden. The blog assumes a plain `init.lua` + vim-plug; your config (`~/.dotfiles/nvim`, symlinked to `~/.config/nvim`) is **LazyVim** on **nvim 0.12.2**, so the blog's snippets get adapted into LazyVim plugin specs instead of pasted into `init.lua`. LazyVim has no gdscript extra, but the installed nvim-lspconfig already ships `lsp/gdscript.lua` (TCP connect to 127.0.0.1:6005), so no hand-written LSP file is needed.

## Changes (all in `~/.dotfiles/nvim`)

0. Save this plan as `docs/godotNeovimSetup.md` (per your CLAUDE.md planning rule).

1. **New `lua/config/godot.lua`** — Godot project detection + server pipe (blog step 1)
   - Check `cwd/project.godot` and `cwd/../project.godot`; expose `M.is_project` / `M.root`.
   - If it's a Godot project, `vim.fn.serverstart(root .. "/server.pipe")`. Improvement over the blog: if a stale `server.pipe` exists (nvim crashed), remove it and start anyway, wrapped in `pcall`, so it doesn't silently break.
   - Required from `init.lua` before `require("config.lazy")`, so other specs can read `require("config.godot").is_project`.

2. **New `lua/plugins/godot.lua`** — LazyVim specs:
   - `neovim/nvim-lspconfig`: `servers = { gdscript = { mason = false } }` (blog step 3; Godot itself is the server, nothing to install).
   - `nvim-treesitter/nvim-treesitter`: append `gdscript`, `godot_resource`, `gdshader` to `opts.ensure_installed` (blog step 4; LazyVim already handles highlight enable).
   - Breakpoint commands (blog step 5) `GodotBreakpoint`, `GodotDeleteBreakpoints`, `GodotFindBreakpoints`, mapped buffer-locally on `gdscript` files. **Keymaps changed from the blog** because `<leader>b` is LazyVim's buffer prefix and `<leader>db` is DAP: use `<leader>Gb` (add), `<leader>GD` (delete all), `<leader>GF` (find), with a which-key "godot" group.

3. **Edit `lua/plugins/oil.lua`** — add `view_options.is_always_hidden` hiding `*.uid` and `server.pipe` when in a Godot project (blog step 6; NERDTree part skipped, you use Oil).

4. **Godot editor settings (manual, done by you in Godot)** — Editor → Editor Settings:
   - Text Editor › External: Use External Editor ✔, Exec Path `/opt/homebrew/bin/nvim`, Exec Flags:
     `--server {project}/server.pipe --remote-send "<C-\><C-N>:e {file}<CR>:call cursor({line}+1,{col})<CR>"`
   - Network › Language Server: Use Thread ✔
   - Script editor → Debug menu: "Debug with External Editor" ✔
   - Add `server.pipe` to each Godot project's `.gitignore`.

## Workflow note
Nvim must already be running (in a terminal, launched from the project dir or one level below) for Godot's click-to-open to work; Godot must be open for the LSP (port 6005) to connect.

## Verification
- `nvim --headless "+lua print(vim.inspect(require('config.godot')))" +qa` in a Godot project and outside one.
- In a Godot project: open nvim, confirm `server.pipe` exists; from another shell run `nvim --server ./server.pipe --remote-send ':e project.godot<CR>'` and confirm it opens.
- With Godot open: open a `.gd` file, `:checkhealth vim.lsp` / `:LspInfo` shows gdscript attached; `K` / `gd` work; `:InspectTree` shows the gdscript parser.
- `:Oil` in the project hides `.uid` files; `<leader>Gb` inserts `breakpoint` and saves.
- Open nvim in a non-Godot dir: no pipe created, no errors.

---

# Debugging with nvim-dap / dap-ui

Godot 4's editor runs a Debug Adapter Protocol server on TCP 6006 (Editor Settings > Network > Debug Adapter).
`lua/plugins/godot.lua` registers a `godot` server adapter (port overridable via `GDScript_DAP_Port`) and two
`gdscript` launch configs: main scene, and the scene currently open in the Godot editor (`launch_scene = true`).
dap-ui comes from LazyVim's `dap.core` extra and opens/closes with the session.

Godot settings: leave Debug Adapter port at 6006; optionally enable **Sync Breakpoints**.

Workflow (Godot editor must be open): `<leader>db` toggle breakpoint, `<leader>dc` pick a Godot config,
step with `<leader>dO` / `<leader>di` / `<leader>do`, `<leader>dt` to stop.

The `breakpoint`-keyword commands (`:GodotBreakpoint`, `:GodotDeleteBreakpoints`, `:GodotFindBreakpoints`)
remain available without keymaps.
