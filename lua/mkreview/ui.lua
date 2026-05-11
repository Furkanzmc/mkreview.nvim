local state = require("mkreview.state")
local utils = require("mkreview.utils")
local M = {}

--- Prompts the user for a review and saves it.
--- @param opts? table Optional range {line1, line2}
function M.add_review(opts)
    local range
    if opts and opts.line1 and opts.line2 then
        range = {
            start_line = opts.line1,
            end_line = opts.line2,
            start_col = 1,
            end_col = #vim.fn.getline(opts.line2),
        }
    else
        range = utils.get_selection()
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local mkreview = require("mkreview")
    local config = mkreview.config

    -- Ensure the sign is defined before placing it
    vim.fn.sign_define("MkReviewSign", {
        text = config.sign_text,
        texthl = config.sign_hl,
    })

    local function on_confirm(input)
        if not input or input == "" then
            mkreview.notify("Review cancelled or empty.\n", vim.log.levels.WARN)
            return
        end

        state.add_review {
            bufnr = bufnr,
            filename = filename,
            start_line = range.start_line,
            start_col = range.start_col,
            end_line = range.end_line,
            end_col = range.end_col,
            comment = input,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }

        -- Add sign to the gutter for all lines in the range
        for line = range.start_line, range.end_line do
            vim.fn.sign_place(0, "MkReviewGroup", "MkReviewSign", bufnr, {
                lnum = line,
                priority = 10,
            })
        end

        local current_session = state.get_current_session()
        mkreview.notify(string.format("Review added to session: %s\n", current_session.name))
    end
    if config.custom_ui then
        config.custom_ui({ prompt = "Review Comment: " }, on_confirm)
    else
        vim.ui.input({ prompt = "Review Comment: " }, on_confirm)
    end
end

--- Refreshes the gutter signs for the current session's active reviews.
function M.refresh_signs()
    vim.fn.sign_unplace("MkReviewGroup")
    local current_session = state.get_current_session()
    local config = require("mkreview").config

    -- Re-define the sign just in case
    vim.fn.sign_define("MkReviewSign", {
        text = config.sign_text,
        texthl = config.sign_hl,
    })

    for _, review in ipairs(current_session.active_reviews) do
        -- Only place signs for buffers that are still valid/loaded
        if vim.api.nvim_buf_is_valid(review.bufnr) then
            for line = review.start_line, review.end_line do
                vim.fn.sign_place(0, "MkReviewGroup", "MkReviewSign", review.bufnr, {
                    lnum = line,
                    priority = 10,
                })
            end
        end
    end
end

--- Lists active reviews in the current session and allows jumping to them.
function M.list_reviews()
    local current_session = state.get_current_session()
    local reviews = current_session.active_reviews
    local mkreview = require("mkreview")

    if #reviews == 0 then
        mkreview.notify(
            string.format("No active reviews in session: %s\n", current_session.name),
            vim.log.levels.WARN
        )
        return
    end

    if mkreview.config.custom_list_ui then
        local items = {}
        for i, review in ipairs(reviews) do
            local filename = vim.fn.fnamemodify(review.filename, ":t")
            -- Handle multi-line comments for display
            local display_comment = review.comment:gsub("\n", " ")
            table.insert(
                items,
                string.format("%d: [%s:%d] %s", i, filename, review.start_line, display_comment)
            )
        end

        local function on_select(_, idx)
            if not idx then
                return
            end

            local review = reviews[idx]
            vim.cmd("edit " .. vim.fn.fnameescape(review.filename))
            vim.api.nvim_win_set_cursor(0, { review.start_line, review.start_col - 1 })
        end

        mkreview.config.custom_list_ui({
            items = items,
            prompt = string.format("Session [%s] - Active Reviews:", current_session.name),
        }, on_select)
    else
        local qf_items = {}
        for _, review in ipairs(reviews) do
            -- Handle multi-line comments for quickfix display
            local display_comment = review.comment:gsub("\n", " ")
            table.insert(qf_items, {
                bufnr = review.bufnr,
                filename = review.filename,
                lnum = review.start_line,
                col = review.start_col,
                text = display_comment,
            })
        end

        vim.fn.setqflist(qf_items, "r")
        vim.fn.setqflist({}, "a", { title = string.format("MkReview: %s", current_session.name) })
        vim.cmd("copen")
    end
end

--- Lists session history (snapshots) and allows viewing reviews within them.
function M.list_history()
    local current_session = state.get_current_session()
    local history = current_session.history
    local mkreview = require("mkreview")

    if #history == 0 then
        mkreview.notify(
            string.format("No history in session: %s\n", current_session.name),
            vim.log.levels.WARN
        )
        return
    end

    local snapshot_items = {}
    for i, snapshot in ipairs(history) do
        table.insert(
            snapshot_items,
            string.format("%d: Dumped at %s (%d reviews)", i, snapshot.dumped_at, #snapshot.reviews)
        )
    end

    vim.ui.select(snapshot_items, {
        prompt = "Select Snapshot to view:",
    }, function(_, snapshot_idx)
        if not snapshot_idx then
            return
        end

        local snapshot = history[snapshot_idx]
        local qf_items = {}
        for _, review in ipairs(snapshot.reviews) do
            -- Handle multi-line comments for display
            local display_comment = review.comment:gsub("\n", " ")
            table.insert(qf_items, {
                bufnr = review.bufnr,
                filename = review.filename,
                lnum = review.start_line,
                col = review.start_col,
                text = display_comment,
            })
        end

        vim.fn.setqflist(qf_items, "r")
        vim.fn.setqflist({}, "a", {
            title = string.format("MkReview Snap %d: %s", snapshot_idx, current_session.name),
        })
        vim.cmd("copen")
    end)
end

--- Lists all sessions and allows switching to them.
function M.list_sessions()
    local sessions = state.get_sessions()
    local mkreview = require("mkreview")
    local config = mkreview.config

    local session_ids = {}
    local items = {}
    for id, session in pairs(sessions) do
        local prefix = (id == state.current_session_id) and "* " or "  "
        table.insert(
            items,
            string.format("%s%s (%d reviews)", prefix, session.name, #session.active_reviews)
        )
        table.insert(session_ids, id)
    end

    local function on_select(_, idx)
        if not idx then
            return
        end
        local selected_id = session_ids[idx]
        state.switch_session(selected_id)
        M.refresh_signs()
        mkreview.notify(string.format("Switched to session: %s\n", sessions[selected_id].name))
    end

    if config.custom_list_ui then
        config.custom_list_ui({
            items = items,
            prompt = "Switch Session:",
        }, on_select)
    else
        vim.ui.select(items, {
            prompt = "Switch Session:",
        }, on_select)
    end
end

--- Prompts to create a new session.
function M.new_session()
    local mkreview = require("mkreview")
    vim.ui.input({ prompt = "New Session Name: " }, function(name)
        if not name or name == "" then
            return
        end
        local id = state.create_session(name)
        state.switch_session(id)
        M.refresh_signs()
        mkreview.notify(string.format("Created and switched to session: %s\n", name))
    end)
end

--- Removes review(s) for the current line or a range of lines.
--- @param opts? table Optional range {line1, line2}
function M.delete_review(opts)
    local start_line, end_line
    if opts and opts.line1 and opts.line2 then
        start_line = opts.line1
        end_line = opts.line2
    else
        local pos = vim.api.nvim_win_get_cursor(0)
        start_line = pos[1]
        end_line = pos[1]
    end

    local bufnr = vim.api.nvim_get_current_buf()
    state.delete_reviews(bufnr, start_line, end_line)
    M.refresh_signs()

    local mkreview = require("mkreview")
    mkreview.notify(string.format("Reviews deleted in range %d-%d.\n", start_line, end_line))
end

--- Shows the review(s) associated with the current cursor line.
function M.show_at_cursor()
    local mkreview = require("mkreview")
    local session = state.get_current_session()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]

    local found = {}

    -- Check active reviews
    for _, review in ipairs(session.active_reviews) do
        if review.bufnr == bufnr and line >= review.start_line and line <= review.end_line then
            table.insert(
                found,
                { type = "Active", comment = review.comment, time = review.timestamp }
            )
        end
    end

    -- Check history
    for i, snapshot in ipairs(session.history) do
        for _, review in ipairs(snapshot.reviews) do
            if review.bufnr == bufnr and line >= review.start_line and line <= review.end_line then
                table.insert(found, {
                    type = "History (Snap " .. i .. ")",
                    comment = review.comment,
                    time = review.timestamp,
                })
            end
        end
    end

    if #found == 0 then
        mkreview.notify("No reviews found for this line.\n", vim.log.levels.WARN)
        return
    end

    local msg = ""
    for _, f in ipairs(found) do
        msg = msg .. string.format("[%s] %s\n", f.type, f.comment)
    end
    mkreview.notify(msg)
end

--- Opens the preview window with a markdown buffer for review input.
--- @param opts table
--- @param callback function
function M.preview_input(opts, callback)
    -- Create a temporary buffer name
    local buf_name = "[MkReview Comment]"
    vim.cmd("pedit " .. vim.fn.fnameescape(buf_name))

    -- Switch to the preview window
    vim.cmd("wincmd P")

    local bufnr = vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()

    -- Configure buffer
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

    -- Show prompt as a comment in the buffer if provided
    if opts.prompt then
        vim.api.nvim_buf_set_lines(
            bufnr,
            0,
            -1,
            false,
            { "<!-- " .. opts.prompt .. " -->", "", "" }
        )
        vim.api.nvim_win_set_cursor(winnr, { 3, 0 })
    end

    local submitted = false
    local function confirm(internal_opts)
        if submitted then
            return
        end
        internal_opts = internal_opts or {}

        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        -- Filter out the prompt comment if we added it
        if opts.prompt and lines[1] and lines[1]:match("^<!%-%-.*%-%->") then
            table.remove(lines, 1)
            if lines[1] == "" then
                table.remove(lines, 1)
            end
        end

        local input = table.concat(lines, "\n")
        input = input:gsub("^%s*", ""):gsub("%s*$", "") -- Trim

        submitted = true
        -- Set buffer as not modified so we can close it without error
        vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

        if not internal_opts.from_autocmd then
            vim.cmd("pclose")
        end

        if input == "" then
            callback(nil)
        else
            callback(input)
        end
    end

    local function cancel()
        if submitted then
            return
        end
        submitted = true
        callback(nil)
    end

    -- Support :w, :wq, :x
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = bufnr,
        callback = function()
            confirm { from_autocmd = true }
        end,
    })

    -- Cancel if closed without saving
    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = bufnr,
        callback = cancel,
    })

    vim.cmd("startinsert")
end

return M
