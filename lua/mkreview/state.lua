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
---@field github_review_id number|string|nil
---@field github_pr_number number|string|nil

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
            github_review_id = nil,
            github_pr_number = nil,
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
    if #session.active_reviews == 0 then return end

    table.insert(session.history, {
        reviews = vim.deepcopy(session.active_reviews),
        dumped_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    })
    session.active_reviews = {}
end

---Clears the current session's active reviews and GitHub metadata.
function M.clear_current_active()
    local session = M.get_current_session()
    session.active_reviews = {}
    session.github_review_id = nil
    session.github_pr_number = nil
end

---Sets the GitHub metadata for the current session.
---@param pr_number number|string
---@param review_id? number|string
function M.set_github_metadata(pr_number, review_id)
    local session = M.get_current_session()
    session.github_pr_number = pr_number
    if review_id then
        session.github_review_id = review_id
    end
end

---Deletes a session.
---@param id string
function M.delete_session(id)
    if id == "default" then return end
    M.sessions[id] = nil
    if M.current_session_id == id then
        M.current_session_id = "default"
    end
end

ensure_default_session()

return M
