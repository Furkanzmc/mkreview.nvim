local state = require("mkreview.state")
local config = require("mkreview").config
local M = {}

--- Dumps the current session's active reviews to a scratch buffer.
function M.dump()
    local mkreview = require("mkreview")
    local session = state.get_current_session()
    local reviews = session.active_reviews

    if #reviews == 0 then
        mkreview.notify(
            string.format("No active reviews to export in session: %s", session.name),
            vim.log.levels.WARN
        )
        return
    end

    local data = {
        session_id = session.id,
        session_name = session.name,
        dumped_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        reviews = reviews,
    }

    local json_data = vim.fn.json_encode(data)
    local lines = vim.split(json_data, "\n")

    -- Create a scratch buffer
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
    vim.api.nvim_buf_set_option(bufnr, "filetype", "json")

    -- Find a unique buffer name
    local base_name = "MkReview Output"
    local final_name = base_name
    local counter = 1
    while vim.fn.bufexists(final_name) ~= 0 do
        final_name = string.format("%s (%d)", base_name, counter)
        counter = counter + 1
    end
    vim.api.nvim_buf_set_name(bufnr, final_name)

    -- Set the JSON content
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    -- Open the buffer in a split
    vim.api.nvim_command("vsplit")
    vim.api.nvim_win_set_buf(0, bufnr)

    -- Add buffer-local command to convert to GitHub format
    vim.api.nvim_buf_create_user_command(bufnr, "MkReviewToGithub", function()
        local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        local success, decoded = pcall(vim.fn.json_decode, content)
        if not success then
            mkreview.notify("Failed to decode JSON in buffer.", vim.log.levels.ERROR)
            return
        end

        local github_format = {
            body = string.format("Review session: %s", decoded.session_name or "Untitled"),
            event = "COMMENT",
            comments = {},
        }

        local root = vim.fn.getcwd() .. "/"
        for _, review in ipairs(decoded.reviews or {}) do
            local relative_path = review.filename:gsub("^" .. vim.pesc(root), "")
            table.insert(github_format.comments, {
                path = relative_path,
                line = review.end_line,
                body = review.comment,
            })
        end

        local encoded = vim.fn.json_encode(github_format)

        local gh_bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(gh_bufnr, "buftype", "nofile")
        vim.api.nvim_buf_set_option(gh_bufnr, "bufhidden", "wipe")
        vim.api.nvim_buf_set_option(gh_bufnr, "swapfile", false)
        vim.api.nvim_buf_set_option(gh_bufnr, "filetype", "json")

        -- Find a unique buffer name for the GitHub payload
        local gh_base_name = "GitHub Review Payload"
        local gh_final_name = gh_base_name
        local gh_counter = 1
        while vim.fn.bufexists(gh_final_name) ~= 0 do
            gh_final_name = string.format("%s (%d)", gh_base_name, gh_counter)
            gh_counter = gh_counter + 1
        end
        vim.api.nvim_buf_set_name(gh_bufnr, gh_final_name)

        vim.api.nvim_buf_set_lines(gh_bufnr, 0, -1, false, vim.split(encoded, "\n"))

        -- Set makeprg to publish via gh CLI
        -- Use $* so the user can pass the PR number to :make
        local cmd = "gh api repos/:owner/:repo/pulls/$*/reviews --input -"
        vim.api.nvim_buf_set_option(gh_bufnr, "makeprg", cmd)

        -- Open the new buffer in a split
        vim.api.nvim_command("vsplit")
        vim.api.nvim_win_set_buf(0, gh_bufnr)

        -- Re-format if formatprg is set
        local inner_formatprg = vim.api.nvim_buf_get_option(gh_bufnr, "formatprg")
        if inner_formatprg ~= "" then
            vim.api.nvim_command("normal! gqG")
        end

        mkreview.notify("GitHub payload created. Run ':make <PR_NUMBER>' to publish.")
    end, { desc = "Transform current JSON to GitHub API format and prepare for publishing" })

    -- Format if formatprg is set
    local formatprg = vim.api.nvim_buf_get_option(bufnr, "formatprg")
    if formatprg ~= "" then
        vim.api.nvim_command("normal! gqG")
    end

    -- Push to history and clear active
    state.push_current_to_history()
    -- Clear signs from the gutter
    vim.fn.sign_unplace("MkReviewGroup")

    mkreview.notify("Reviews dumped to scratch buffer and pushed to history.")
end

return M
