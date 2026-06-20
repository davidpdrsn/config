local M = {}

local registry_root = os.getenv("PI_NVIM_SERVER_DIR") or "/tmp/pi-nvim-servers"
local current_marker = nil

local function real_cwd()
    return vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()
end

local function cwd_hash(cwd)
    return vim.fn.sha256(cwd)
end

local function ensure_server()
    if vim.v.servername ~= nil and vim.v.servername ~= "" then
        return vim.v.servername
    end

    local ok, servername = pcall(vim.fn.serverstart)
    if ok and type(servername) == "string" and servername ~= "" then
        return servername
    end

    return nil
end

local function marker_path(cwd)
    return registry_root .. "/" .. cwd_hash(cwd) .. "/" .. vim.uv.os_getpid() .. ".json"
end

local function remove_marker()
    if current_marker ~= nil then
        pcall(vim.fn.delete, current_marker)
        current_marker = nil
    end
end

local function write_marker()
    local servername = ensure_server()
    if servername == nil then
        return
    end

    local cwd = real_cwd()
    local path = marker_path(cwd)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

    local data = {
        address = servername,
        cwd = cwd,
        pid = vim.uv.os_getpid(),
    }

    vim.fn.writefile({ vim.json.encode(data) }, path)
    current_marker = path
end

local function refresh_marker()
    remove_marker()
    write_marker()
end

local function realpath_or_self(file)
    return vim.uv.fs_realpath(file) or file
end

local function sync_lsp_for_buffer(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
        return
    end

    if vim.bo[bufnr].modified then
        return
    end

    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    if #clients == 0 then
        return
    end

    local uri = vim.uri_from_bufnr(bufnr)
    local version = vim.lsp.util.buf_versions[bufnr] + 1
    vim.lsp.util.buf_versions[bufnr] = version

    local did_change = vim.lsp.protocol.Methods.textDocument_didChange
    local did_save = vim.lsp.protocol.Methods.textDocument_didSave
    local full_text = vim.lsp._buf_get_full_text(bufnr)

    for _, client in ipairs(clients) do
        if client:supports_method(did_change, bufnr) then
            client:notify(did_change, {
                textDocument = {
                    uri = uri,
                    version = version,
                },
                contentChanges = {
                    { text = full_text },
                },
            })
        end

        if client:supports_method(did_save, bufnr) then
            client:notify(did_save, {
                textDocument = { uri = uri },
            })
        end
    end
end

local function buffer_matches_path(bufnr, changed_paths)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" then
        return false
    end

    return changed_paths[realpath_or_self(name)] == true
end

function M.reload_files(paths)
    local changed_paths = {}
    for _, file in ipairs(paths or {}) do
        changed_paths[realpath_or_self(file)] = true
    end

    vim.cmd("checktime")

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if buffer_matches_path(bufnr, changed_paths) then
            pcall(function()
                require("live_diff").reload(bufnr)
            end)
            sync_lsp_for_buffer(bufnr)
        end
    end
end

function M.reload_files_base64(encoded)
    local ok, decoded = pcall(vim.base64.decode, encoded)
    if not ok then
        return
    end

    local paths_ok, paths = pcall(vim.json.decode, decoded)
    if not paths_ok or type(paths) ~= "table" then
        return
    end

    M.reload_files(paths)
end

function M.setup()
    write_marker()

    vim.api.nvim_create_autocmd("DirChanged", {
        group = vim.api.nvim_create_augroup("PiNvimServer", { clear = true }),
        callback = refresh_marker,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("PiNvimServerCleanup", { clear = true }),
        callback = remove_marker,
    })
end

return M
