--- @brief This plugin was autonomously developed by Gemini CLI (an AI assistant).
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

---@class Snapshot
---@field reviews Review[]
---@field dumped_at string

---@class Session
---@field id string
---@field name string
---@field active_reviews Review[]
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
            history = {},
            created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            github_review_node_id = nil,
            github_pr_number = nil,
            github_pr_node_id = nil,
            github_commit_id = nil,
        }
    end
end

---Adds a new review to the current session's active reviews.
---@param review Review
function M.add_review(review)
    ensure_default_session()
    table.insert(M.sessions[M.current_session_id].active_reviews, review)
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
        history = {},
        created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        github_review_id = nil,
        github_pr_number = nil,
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
        local overlap = review.bufnr == bufnr
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

ensure_default_session()

return M
