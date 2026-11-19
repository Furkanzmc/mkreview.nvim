local M = {}

--- Gets the current selection range.
--- @return table
function M.get_selection()
    local mode = vim.fn.mode()
    local start_line, start_col, end_line, end_col

    if mode:match("[vV]") then
        -- Visual mode range
        local start_pos = vim.fn.getpos("v")
        local end_pos = vim.fn.getpos(".")
        start_line = start_pos[2]
        start_col = start_pos[3]
        end_line = end_pos[2]
        end_col = end_pos[3]

        -- Ensure start is before end
        if start_line > end_line or (start_line == end_line and start_col > end_col) then
            start_line, end_line = end_line, start_line
            start_col, end_col = end_col, start_col
        end
    else
        -- Normal mode (current line)
        local pos = vim.fn.getpos(".")
        start_line = pos[2]
        end_line = pos[2]
        start_col = 1
        end_col = #vim.fn.getline(".")
    end

    return {
        start_line = start_line,
        start_col = start_col,
        end_line = end_line,
        end_col = end_col,
    }
end

local function normalize_path(path)
    if not path or path == "" then
        return path
    end

    local p = (vim.fs and vim.fs.normalize) and vim.fs.normalize(path) or path:gsub("\\", "/")
    local prefix = ""
    if p:match("^%a:/") then
        prefix = p:sub(1, 3)
        p = p:sub(4)
    elseif p:sub(1, 1) == "/" then
        prefix = "/"
        p = p:sub(2)
    end

    local parts = {}
    for seg in p:gmatch("[^/]+") do
        if seg == "." then
            -- skip current-dir segments
        elseif seg == ".." then
            if #parts > 0 and parts[#parts] ~= ".." then
                table.remove(parts)
            elseif prefix == "" then
                table.insert(parts, "..")
            end
        else
            table.insert(parts, seg)
        end
    end

    if prefix ~= "" then
        return prefix .. table.concat(parts, "/")
    end
    if #parts == 0 then
        return "."
    end
    return table.concat(parts, "/")
end

local function is_absolute_path(path)
    return path:sub(1, 1) == "/" or path:match("^%a:/") ~= nil
end

local function split_path(path)
    local prefix = ""
    local rest = path
    if rest:match("^%a:/") then
        prefix = rest:sub(1, 3):lower()
        rest = rest:sub(4)
    elseif rest:sub(1, 1) == "/" then
        prefix = "/"
        rest = rest:sub(2)
    end

    local parts = {}
    for seg in rest:gmatch("[^/]+") do
        table.insert(parts, seg)
    end
    return prefix, parts
end

local function compute_relative(norm_path, norm_base)
    local path_prefix, path_parts = split_path(norm_path)
    local base_prefix, base_parts = split_path(norm_base)

    if path_prefix ~= base_prefix then
        return norm_path, false
    end

    local common = 0
    local min_len = math.min(#path_parts, #base_parts)
    while common < min_len and path_parts[common + 1] == base_parts[common + 1] do
        common = common + 1
    end

    local rel_parts = {}
    for _ = common + 1, #base_parts do
        table.insert(rel_parts, "..")
    end
    for i = common + 1, #path_parts do
        table.insert(rel_parts, path_parts[i])
    end

    local rel = #rel_parts == 0 and "." or table.concat(rel_parts, "/")
    return rel, common == #base_parts
end

--- Converts a file path to a path relative to `base` (defaults to current working directory).
--- @param path string
--- @param base? string
--- @return string
function M.to_relative_path(path, base)
    if not path or path == "" then
        return path
    end

    local norm_path = normalize_path(path)
    if not is_absolute_path(norm_path) then
        return norm_path
    end

    local norm_base = normalize_path(base or vim.fn.getcwd())
    local rel, is_descendant = compute_relative(norm_path, norm_base)

    if not is_descendant then
        local resolved_path = normalize_path(vim.fn.resolve(norm_path))
        local resolved_base = normalize_path(vim.fn.resolve(norm_base))
        if resolved_path ~= norm_path or resolved_base ~= norm_base then
            local resolved_rel, resolved_descendant = compute_relative(resolved_path, resolved_base)
            if resolved_descendant or #resolved_rel < #rel then
                return resolved_rel
            end
        end
    end

    return rel
end

--- Resolves a relative file path against `base` (defaults to current working directory).
--- Already-absolute paths are returned normalized.
--- @param path string
--- @param base? string
--- @return string
function M.to_absolute_path(path, base)
    if not path or path == "" then
        return path
    end

    local norm_path = normalize_path(path)
    if is_absolute_path(norm_path) then
        return norm_path
    end

    local norm_base = normalize_path(base or vim.fn.getcwd())
    local sep = norm_base:sub(-1) == "/" and "" or "/"
    return normalize_path(norm_base .. sep .. norm_path)
end

return M
