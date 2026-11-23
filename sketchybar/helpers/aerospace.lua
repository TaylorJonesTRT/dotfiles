--- aerospace module for sending commands to the AeroSpace window manager server
-- @module Aerospace
-- @copyright 2025
-- @license MIT

local socket                = require("posix.sys.socket")
local unistd                = require("posix.unistd")
local fcntl                 = require("posix.fcntl")
local poll                  = require("posix.poll")
local cjson                 = require("cjson")
local log                   = require("helpers.log").new("aerospace")

-- FD_CLOEXEC explanation:
-- When a process spawns a child (via fork+exec), the child inherits all open
-- file descriptors (FDs) from the parent by default. This includes sockets.
--
-- Problem: If the parent has an open socket to AeroSpace (e.g., FD 5), and then
-- spawns cpu_load/network_load via sbar.exec(), those children also get FD 5.
-- Multiple processes sharing one socket connection causes corruption:
-- - Parent sends a request, but child accidentally reads the response
-- - Socket stream gets out of sync, parent blocks forever waiting for data
--
-- Solution: Set FD_CLOEXEC flag on the socket. This tells the OS to
-- automatically close this FD in child processes after exec().
-- The parent keeps the socket, children don't inherit it.
local function set_cloexec(fd)
    local flags = fcntl.fcntl(fd, fcntl.F_GETFD)
    if flags then
        fcntl.fcntl(fd, fcntl.F_SETFD, flags | fcntl.FD_CLOEXEC)
        log.debug("set FD_CLOEXEC on fd=%d", fd)
    else
        log.warn("failed to get FD flags for fd=%d", fd)
    end
end

-- Try to load simdjson (optional, faster JSON parser)
local simdjson_ok, simdjson = pcall(require, "simdjson")
local use_simd              = simdjson_ok

local DEFAULT               = {
    SOCK_FMT = "/tmp/bobko.aerospace-%s.sock",
    TIMEOUT_MS = 5000,  -- 5 second timeout for socket operations
}

-- Timeout explanation:
-- Without a timeout, read() blocks forever if no data arrives. This can happen if:
-- - AeroSpace is unresponsive or crashed
-- - The socket connection is in a bad state
-- - A previous bug caused socket corruption
--
-- Solution: Use poll() to check if data is available before reading.
-- poll() returns immediately if data is ready, or after timeout_ms if not.
-- This prevents the entire sketchybar lua event loop from freezing.
local function wait_for_data(fd, timeout_ms)
    -- poll() returns: >0 if data ready, 0 if timeout, -1 if error
    local result = poll.rpoll(fd, timeout_ms)
    return result and result > 0
end
local ERR                   = {
    SOCKET   = "socket error",
    NOT_INIT = "socket not connected",
    JSON     = "failed to decode JSON",
}

local AF_UNIX, SOCK_STREAM  = socket.AF_UNIX, socket.SOCK_STREAM
local write, read, close    = unistd.write, unistd.read, unistd.close
local encode                = cjson.encode

-- AeroSpace's socket protocol (as of the NWConnection-based server) requires:
-- 1. A one-time handshake per connection: client writes its protocol version
--    as a raw 4-byte little-endian uint32, server echoes back its own.
-- 2. Every request/response after that is length-prefixed: a 4-byte
--    little-endian uint32 byte count, followed by exactly that many bytes
--    of JSON. See Sources/Common/util/NWConnectionEx.swift and
--    Sources/AppBundle/server.swift in the AeroSpace repo.
local SOCKET_PROTOCOL_VERSION = 1

local function u32le_encode(n)
    return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end

local function u32le_decode(s)
    local b1, b2, b3, b4 = s:byte(1, 4)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function decode(str)
    if use_simd then
        local ok, val = pcall(simdjson.parse, str)
        if ok then return val end
        use_simd = false
    end
    local ok, val = pcall(cjson.decode, str)
    if not ok then error(ERR.JSON .. ": " .. tostring(val)) end
    return val
end

-- Reads exactly `size` bytes from fd, polling with a timeout between reads.
-- Returns the bytes read, or nil if the read timed out or the peer closed.
local function read_exact(fd, size, timeout_ms)
    local chunks = {}
    local remaining = size
    while remaining > 0 do
        if not wait_for_data(fd, timeout_ms) then
            return nil, "timeout"
        end
        local chunk = read(fd, remaining)
        if not chunk or #chunk == 0 then
            return nil, "closed"
        end
        table.insert(chunks, chunk)
        remaining = remaining - #chunk
    end
    return table.concat(chunks)
end

local function handshake(fd)
    log.debug("performing protocol handshake, fd=%d", fd)
    write(fd, u32le_encode(SOCKET_PROTOCOL_VERSION))
    local resp, err = read_exact(fd, 4, DEFAULT.TIMEOUT_MS)
    if not resp then
        log.error("handshake failed: %s", tostring(err))
        error("handshake failed: " .. tostring(err))
    end
    local server_version = u32le_decode(resp)
    if server_version ~= SOCKET_PROTOCOL_VERSION then
        log.error("protocol version mismatch: client=%d server=%d", SOCKET_PROTOCOL_VERSION, server_version)
        error(string.format("protocol version mismatch: client=%d server=%d", SOCKET_PROTOCOL_VERSION, server_version))
    end
    log.debug("handshake ok, server_version=%d", server_version)
end

local function connect(path)
    log.info("connecting to socket: %s", path)
    local fd, err = socket.socket(AF_UNIX, SOCK_STREAM, 0)
    if not fd then
        log.error("socket creation failed: %s", tostring(err))
        error(ERR.SOCKET .. ": " .. tostring(err))
    end

    -- Prevent child processes from inheriting this socket (see FD_CLOEXEC explanation above)
    set_cloexec(fd)

    if socket.connect(fd, { family = AF_UNIX, path = path }) ~= 0 then
        log.error("socket connect failed: %s", path)
        close(fd); error("cannot connect to " .. path)
    end
    log.info("connected successfully, fd=%d", fd)

    local ok, herr = pcall(handshake, fd)
    if not ok then
        close(fd)
        error(herr)
    end

    return fd
end

local function stdout(raw)
    -- Handle empty or whitespace-only responses
    if not raw or raw == "" or raw:match("^%s*$") then
        return ""
    end

    if use_simd then
        local ok, doc = pcall(simdjson.open, raw)
        if ok then
            local stdout_ok, stdout_val = pcall(function() return doc:atPointer("/stdout") end)
            if stdout_ok then
                return stdout_val or ""
            end
        end
        use_simd = false
    end
    -- Fallback: parse JSON manually to extract stdout field
    local ok, json = pcall(cjson.decode, raw)
    if not ok then
        -- JSON parse failed, return empty string instead of crashing
        return ""
    end
    return json.stdout or ""
end

local Aerospace = {}; Aerospace.__index = Aerospace

function Aerospace.new(path)
    if not path then
        local username = io.popen("id -un"):read("*l")
        path = DEFAULT.SOCK_FMT:format(username)
    end

    return setmetatable({
        sockPath = path,
        fd = connect(path),
    }, Aerospace)
end

function Aerospace:close()
    if self.fd then
        log.info("closing socket fd=%d", self.fd)
        close(self.fd); self.fd = nil
    end
end

Aerospace.__gc = Aerospace.close

function Aerospace:reconnect()
    log.warn("reconnecting to aerospace socket")
    self:close(); self.fd = connect(self.sockPath)
end

function Aerospace:is_initialized() return self.fd ~= nil end

local PAYLOAD_TMPL = '{"args":%s,"stdin":""}'
function Aerospace:_query(args, want_json, big)
    -- Auto-reconnect if socket is not initialized
    if not self:is_initialized() then
        log.warn("socket not initialized, attempting auto-reconnect")
        local ok, err = pcall(function() self:reconnect() end)
        if not ok then
            log.error("auto-reconnect failed: %s", tostring(err))
            error(ERR.NOT_INIT)
        end
        if not self:is_initialized() then
            log.error("auto-reconnect succeeded but socket still not initialized")
            error(ERR.NOT_INIT)
        end
        log.info("auto-reconnect successful, resuming query")
    end

    local cmd_name = args[1] or "unknown"
    local start_time = os.clock()
    local body = PAYLOAD_TMPL:format(encode(args))
    local payload = u32le_encode(#body) .. body

    log.debug("query start: %s (fd=%d)", cmd_name, self.fd)
    log.blocking_start("write", string.format("cmd=%s bytes=%d", cmd_name, #payload))
    local write_start = os.clock()
    write(self.fd, payload)
    log.blocking_end("write", (os.clock() - write_start) * 1000)

    -- Response framing: 4-byte little-endian length prefix, then exactly
    -- that many bytes of JSON body.
    log.blocking_start("read", string.format("cmd=%s (length prefix)", cmd_name))
    local read_start = os.clock()
    local len_bytes, len_err = read_exact(self.fd, 4, DEFAULT.TIMEOUT_MS)

    if not len_bytes then
        log.error("failed to read length prefix: cmd=%s err=%s", cmd_name, tostring(len_err))
        log.error("socket in bad state, reconnecting")
        self:reconnect()
        return want_json and {} or ""
    end

    local body_len = u32le_decode(len_bytes)
    local raw, body_err = read_exact(self.fd, body_len, DEFAULT.TIMEOUT_MS)
    log.blocking_end("read", (os.clock() - read_start) * 1000)

    if not raw then
        log.error("failed to read body: cmd=%s expected=%d err=%s", cmd_name, body_len, tostring(body_err))
        log.error("socket in bad state, reconnecting")
        self:reconnect()
        return want_json and {} or ""
    end

    local elapsed_ms = (os.clock() - start_time) * 1000
    log.socket("query_complete", self.fd, #raw, elapsed_ms)

    if elapsed_ms > 500 then
        log.warn("SLOW QUERY: %s took %.2fms, %d bytes", cmd_name, elapsed_ms, #raw)
    end

    local out = stdout(raw)
    return want_json and decode(out) or out
end

local function passthrough(self, argtbl, json, big, cb)
    local res = self:_query(argtbl, json, big)
    return cb and cb(res) or res
end

function Aerospace:list_apps(cb)
    return passthrough(self, { "list-apps", "--json" }, true, nil, cb)
end

function Aerospace:query_workspaces(cb)
    return passthrough(self, {
        "list-workspaces", "--all",
        "--format", "%{workspace-is-focused}%{workspace-is-visible}%{workspace}%{monitor-appkit-nsscreen-screens-id}%{monitor-name}",
        "--json" }, true, true, cb)
end

function Aerospace:list_current(cb)
    return passthrough(self, { "list-workspaces", "--focused" }, false, nil, cb)
end

function Aerospace:list_windows(space, cb)
    return passthrough(self, { "list-windows", "--workspace", space, "--json" }, false, nil, cb)
end

function Aerospace:focused_window(cb)
    return passthrough(self, { "list-windows", "--focused", "--json" }, false, nil, cb)
end

function Aerospace:workspace(ws)
    return self:_query({ "workspace", ws }, false)
end

function Aerospace:list_all_windows(cb)
    return passthrough(self, {
        "list-windows", "--all", "--json",
        "--format", "%{window-id}%{app-name}%{window-title}%{workspace}" }, true, true, cb)
end

function Aerospace:list_modes(current_only, cb)
    local args = current_only and { "list-modes", "--current" } or { "list-modes" }
    return passthrough(self, args, false, nil, cb)
end

function Aerospace:list_monitors(cb)
    return passthrough(self, { "list-monitors" }, false, nil, cb)
end

return Aerospace
