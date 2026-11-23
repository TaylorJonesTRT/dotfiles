-- Godot project detection + server pipe so Godot can open files in this nvim.
-- See docs/godotNeovimSetup.md

local M = { is_project = false, root = nil }

local cwd = vim.fn.getcwd()
for _, rel in ipairs({ "/", "/../" }) do
  if vim.uv.fs_stat(cwd .. rel .. "project.godot") then
    M.is_project = true
    M.root = vim.fs.normalize(cwd .. rel)
    break
  end
end

if M.is_project then
  local pipe = M.root .. "/server.pipe"
  if vim.uv.fs_stat(pipe) then
    -- Another nvim already owns the pipe; leave it alone. Otherwise it's stale.
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", pipe)
    if ok and chan > 0 then
      vim.fn.chanclose(chan)
      pipe = nil
    else
      os.remove(pipe)
    end
  end
  if pipe then
    -- Silently fails if the path exceeds the macOS socket limit (~104 chars)
    pcall(vim.fn.serverstart, pipe)
    if not vim.uv.fs_stat(pipe) then
      vim.notify("Godot: couldn't start server at " .. pipe, vim.log.levels.WARN)
    end
  end
end

return M
