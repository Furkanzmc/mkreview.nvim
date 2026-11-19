--- @brief This plugin was autonomously developed by Gemini CLI (an AI assistant).
local utils = require("mkreview.utils")
local M = {}

---@class Review
---@field bufnr number
---@field filename string
---@field start_line number
---@field end_line number
---@field start_col number
---@field end_col number
---@field comment string
---@field timestamp string

---@class Note
---@field bufnr number
---@field filename string
---@field start_line number
---@field end_line number
---@field start_col number
---@field end_col number
---@field comment string
---@field timestamp string

---@class Snapshot
---@field reviews Review[]
---@field dumped_at string

---@class Session
---@field id string
---@field name string
---@field active_reviews Review[]
---@field notes Note[]
---@field history Snapshot[]
---@field created_at string
---@field github_review_node_id string|nil
---@field github_pr_number number|string|nil
---@field github_pr_node_id string|nil
---@field github_commit_id string|nil

---@type table<string, Session>
M.sessions = {}
M.current_session_id = "default"

---Initializes the default session if it doesn't exist.
local function ensure_default_session()
    if not M.sessions["default"] then
        M.sessions["default"] = {
            id = "default",
            name = "Default Session",
            active_reviews = {},
            notes = {},
            history = {},
            created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            github_review_node_id = nil,
            github_pr_number = nil,
            github_pr_node_id = nil,
            github_commit_id = nil,
        }
    end
end

---Checks if a review or note item matches a buffer by bufnr or filename.
---@param item Review|Note
---@param bufnr number
---@return boolean
local function item_matches_buf(item, bufnr)
    if item.bufnr == bufnr then
        return true
    end
    if item.filename and item.filename ~= "" and vim.api.nvim_buf_is_valid(bufnr) then
        local bname = vim.api.nvim_buf_get_name(bufnr)
        if bname ~= "" and item.filename == bname then
            item.bufnr = bufnr
            return true
        end
    end
    return false
end

---Adds a new review to the current session's active reviews.
---@param review Review
function M.add_review(review)
    ensure_default_session()
    table.insert(M.sessions[M.current_session_id].active_reviews, review)
end

---Finds all active reviews at the given line in a buffer.
---@param bufnr number
---@param line number
---@return Review[]
function M.get_reviews_at_line(bufnr, line)
    local session = M.get_current_session()
    local matches = {}
    for _, review in ipairs(session.active_reviews or {}) do
        if item_matches_buf(review, bufnr) and line >= review.start_line and line <= review.end_line then
            table.insert(matches, review)
        end
    end
    return matches
end

---Finds an active review at the given line in a buffer.
---@param bufnr number
---@param line number
---@return Review|nil
function M.get_review_at_line(bufnr, line)
    return M.get_reviews_at_line(bufnr, line)[1]
end

---Updates the comment of an existing review.
---@param review Review
---@param new_comment string
function M.update_review(review, new_comment)
    review.comment = new_comment
    review.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
end

---Adds a new note to the current session.
---@param note Note
function M.add_note(note)
    ensure_default_session()
    local session = M.sessions[M.current_session_id]
    session.notes = session.notes or {}
    table.insert(session.notes, note)
end

---Finds a note at the given line in a buffer.
---@param bufnr number
---@param line number
---@return Note|nil
function M.get_note_at_line(bufnr, line)
    local session = M.get_current_session()
    session.notes = session.notes or {}
    for _, note in ipairs(session.notes) do
        if item_matches_buf(note, bufnr) and line >= note.start_line and line <= note.end_line then
            return note
        end
    end
    return nil
end

---Updates the comment of an existing note.
---@param note Note
---@param new_comment string
function M.update_note(note, new_comment)
    note.comment = new_comment
    note.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
end

---Removes notes that overlap with the given line range in a buffer.
---@param bufnr number
---@param start_line number
---@param end_line number
function M.delete_notes(bufnr, start_line, end_line)
    local session = M.get_current_session()
    session.notes = session.notes or {}
    local new_notes = {}
    for _, note in ipairs(session.notes) do
        local overlap = item_matches_buf(note, bufnr)
            and not (note.end_line < start_line or note.start_line > end_line)
        if not overlap then
            table.insert(new_notes, note)
        end
    end
    session.notes = new_notes
end

---Creates a new session.
---@param name string
---@return string id The generated session ID
function M.create_session(name)
    local id = string.lower(name:gsub("%s+", "-"))
    if M.sessions[id] then
        id = id .. "-" .. os.time()
    end

    M.sessions[id] = {
        id = id,
        name = name,
        active_reviews = {},
        notes = {},
        history = {},
        created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        github_review_node_id = nil,
        github_pr_number = nil,
        github_pr_node_id = nil,
        github_commit_id = nil,
    }
    return id
end

---Switches the current session.
---@param id string
---@return boolean success
function M.switch_session(id)
    if M.sessions[id] then
        M.current_session_id = id
        return true
    end
    return false
end

---Returns all sessions.
---@return table<string, Session>
function M.get_sessions()
    ensure_default_session()
    return M.sessions
end

---Returns the current session.
---@return Session
function M.get_current_session()
    ensure_default_session()
    return M.sessions[M.current_session_id]
end

---Pushes the current active reviews into history and clears them.
function M.push_current_to_history()
    local session = M.get_current_session()
    if #session.active_reviews == 0 then
        return
    end

    table.insert(session.history, {
        reviews = vim.deepcopy(session.active_reviews),
        dumped_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    session.active_reviews = {}
end

---Removes reviews that overlap with the given line range in a buffer.
---@param bufnr number
---@param start_line number
---@param end_line number
function M.delete_reviews(bufnr, start_line, end_line)
    local session = M.get_current_session()
    local new_reviews = {}
    for _, review in ipairs(session.active_reviews) do
        -- A review overlaps if its range [review.start_line, review.end_line]
        -- intersects with the target range [start_line, end_line].
        local overlap = item_matches_buf(review, bufnr)
            and not (review.end_line < start_line or review.start_line > end_line)
        if not overlap then
            table.insert(new_reviews, review)
        end
    end
    session.active_reviews = new_reviews
end

---Clears the current session's active reviews and GitHub metadata.
function M.clear_current_active()
    local session = M.get_current_session()
    session.active_reviews = {}
    session.github_review_node_id = nil
    session.github_pr_number = nil
    session.github_pr_node_id = nil
    session.github_commit_id = nil
end

---Sets the GitHub metadata for the current session.
---@param pr_number number|string
---@param review_node_id? string
---@param commit_id? string
---@param pr_node_id? string
function M.set_github_metadata(pr_number, review_node_id, commit_id, pr_node_id)
    local session = M.get_current_session()
    session.github_pr_number = pr_number
    if review_node_id then
        session.github_review_node_id = review_node_id
    end
    if commit_id then
        session.github_commit_id = commit_id
    end
    if pr_node_id then
        session.github_pr_node_id = pr_node_id
    end
end

---Deletes a session.
---@param id string
function M.delete_session(id)
    if id == "default" then
        return
    end
    M.sessions[id] = nil
    if M.current_session_id == id then
        M.current_session_id = "default"
    end
end

---Returns the full current session data table formatted for JSON dumping.
---All file paths are converted to paths relative to the current working directory.
---@return table
function M.dump_session_data()
    local session = M.get_current_session()
    local cwd = vim.fn.getcwd()

    local function relativize_items(items)
        local result = vim.deepcopy(items or {})
        for _, item in ipairs(result) do
            if item.filename and item.filename ~= "" then
                item.filename = utils.to_relative_path(item.filename, cwd)
            end
        end
        return result
    end

    local history = vim.deepcopy(session.history or {})
    for _, snap in ipairs(history) do
        if snap.reviews then
            for _, rev in ipairs(snap.reviews) do
                if rev.filename and rev.filename ~= "" then
                    rev.filename = utils.to_relative_path(rev.filename, cwd)
                end
            end
        end
    end

    return {
        version = 1,
        id = session.id,
        name = session.name,
        created_at = session.created_at,
        github_pr_number = session.github_pr_number,
        github_review_node_id = session.github_review_node_id,
        github_commit_id = session.github_commit_id,
        github_pr_node_id = session.github_pr_node_id,
        active_reviews = relativize_items(session.active_reviews),
        notes = relativize_items(session.notes),
        history = history,
    }
end

---Loads decoded session data into a newly created session.
---Supports both MkReview internal session format and GitHub Review JSON format.
---@param data table Decoded JSON table
---@param custom_name? string Optional override for the session name
---@return string|nil id The generated session ID, or nil on failure
---@return string|nil error_msg
function M.load_session_data(data, custom_name)
    if type(data) ~= "table" then
        return nil, "Invalid session data: expected JSON object or array."
    end

    local is_list = (vim.islist and vim.islist(data)) or (type(data[1]) == "table")
    local is_github_format = is_list or (data.comments ~= nil and type(data.comments) == "table")

    local name
    if custom_name and custom_name ~= "" then
        name = custom_name
    elseif not is_github_format and data.name then
        name = data.name
    elseif is_github_format and type(data.body) == "string" and data.body:match("^Review session:%s*(.+)") then
        name = data.body:match("^Review session:%s*(.+)")
    elseif is_github_format and type(data.body) == "string" and data.body ~= "" then
        name = data.body:sub(1, 30)
    else
        name = "Imported Session"
    end

    local id = M.create_session(name)
    local session = M.sessions[id]

    -- Resolve relative paths against cwd and attach buffer numbers if already loaded
    local cwd = vim.fn.getcwd()
    local function resolve_item(item)
        if item.filename and item.filename ~= "" then
            item.filename = utils.to_absolute_path(item.filename, cwd)
            local bufnr = vim.fn.bufnr(item.filename)
            if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
                item.bufnr = bufnr
            else
                item.bufnr = -1
            end
        else
            item.bufnr = -1
        end
    end

    if is_github_format then
        -- Convert GitHub-compatible review JSON into mkreview format
        local raw_comments = is_list and data or data.comments or {}

        session.created_at = data.created_at or os.date("!%Y-%m-%dT%H:%M:%SZ")
        session.github_review_node_id = data.node_id or data.review_node_id or data.id
        session.github_commit_id = data.commit_id
        session.github_pr_number = data.pull_request_number or data.pr_number
        session.notes = {}
        session.history = {}
        session.active_reviews = {}

        for _, comment in ipairs(raw_comments) do
            local rel_path = comment.path or comment.filename or ""
            local full_path = utils.to_absolute_path(rel_path, cwd)

            local start_line = tonumber(comment.start_line) or tonumber(comment.line) or 1
            local end_line = tonumber(comment.line) or start_line
            if start_line > end_line then
                start_line, end_line = end_line, start_line
            end

            local rev = {
                bufnr = -1,
                filename = full_path,
                start_line = start_line,
                start_col = 1,
                end_line = end_line,
                end_col = 1,
                comment = comment.body or "",
                timestamp = comment.created_at or os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }
            resolve_item(rev)
            table.insert(session.active_reviews, rev)
        end
    else
        -- Native internal session format
        session.created_at = data.created_at or os.date("!%Y-%m-%dT%H:%M:%SZ")
        session.github_pr_number = data.github_pr_number
        session.github_review_node_id = data.github_review_node_id
        session.github_commit_id = data.github_commit_id
        session.github_pr_node_id = data.github_pr_node_id
        session.active_reviews = data.active_reviews or {}
        session.notes = data.notes or {}
        session.history = data.history or {}

        for _, rev in ipairs(session.active_reviews) do
            resolve_item(rev)
        end
        for _, note in ipairs(session.notes) do
            resolve_item(note)
        end
        for _, snap in ipairs(session.history) do
            if snap.reviews then
                for _, rev in ipairs(snap.reviews) do
                    resolve_item(rev)
                end
            end
        end
    end

    return id
end

ensure_default_session()

return M
