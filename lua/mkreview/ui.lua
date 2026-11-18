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
        config.custom_ui({ prompt = "Review Comment: ", is_edit = false }, on_confirm)
    else
        vim.ui.input({ prompt = "Review Comment: " }, on_confirm)
    end
end

--- Refreshes the gutter signs for the current session's active reviews and self notes.
function M.refresh_signs()
    vim.fn.sign_unplace("MkReviewGroup")
    vim.fn.sign_unplace("MkReviewNoteGroup")
    local current_session = state.get_current_session()
    local config = require("mkreview").config

    -- Re-define signs just in case
    vim.fn.sign_define("MkReviewSign", {
        text = config.sign_text,
        texthl = config.sign_hl,
    })
    vim.fn.sign_define("MkReviewNoteSign", {
        text = config.note_sign_text,
        texthl = config.note_sign_hl,
    })

    local function get_valid_buf(item)
        if item.bufnr and vim.api.nvim_buf_is_valid(item.bufnr) and vim.api.nvim_buf_is_loaded(item.bufnr) then
            return item.bufnr
        end
        if item.filename and item.filename ~= "" then
            local b = vim.fn.bufnr(item.filename)
            if b ~= -1 and vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_is_loaded(b) then
                item.bufnr = b
                return b
            end
        end
        return nil
    end

    for _, review in ipairs(current_session.active_reviews or {}) do
        local b = get_valid_buf(review)
        if b then
            for line = review.start_line, review.end_line do
                vim.fn.sign_place(0, "MkReviewGroup", "MkReviewSign", b, {
                    lnum = line,
                    priority = 10,
                })
            end
        end
    end

    for _, note in ipairs(current_session.notes or {}) do
        local b = get_valid_buf(note)
        if b then
            for line = note.start_line, note.end_line do
                vim.fn.sign_place(0, "MkReviewNoteGroup", "MkReviewNoteSign", b, {
                    lnum = line,
                    priority = 11,
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

--- Edits the review on the current cursor line.
function M.edit_review()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local review = state.get_review_at_line(bufnr, line)

    local mkreview = require("mkreview")
    if not review then
        mkreview.notify("No active review found on this line to edit.\n", vim.log.levels.WARN)
        return
    end

    M.preview_input({
        prompt = "Edit Review Comment",
        initial_content = review.comment,
        is_edit = true,
    }, function(new_comment)
        if not new_comment or new_comment == "" then
            return
        end
        state.update_review(review, new_comment)
        mkreview.notify("Review updated.\n")
    end)
end

--- Shows the review(s) associated with the current cursor line.
function M.show_at_cursor()
    local mkreview = require("mkreview")
    local session = state.get_current_session()
    local bufnr = vim.api.nvim_get_current_buf()
    local current_filename = vim.api.nvim_buf_get_name(bufnr)
    local line = vim.api.nvim_win_get_cursor(0)[1]

    local function matches_buf(item)
        return item.bufnr == bufnr or (item.filename and item.filename ~= "" and item.filename == current_filename)
    end

    local found = {}

    -- Check active reviews
    for _, review in ipairs(session.active_reviews or {}) do
        if matches_buf(review) and line >= review.start_line and line <= review.end_line then
            table.insert(
                found,
                { type = "Active", comment = review.comment, time = review.timestamp }
            )
        end
    end

    -- Check notes
    for _, note in ipairs(session.notes or {}) do
        if matches_buf(note) and line >= note.start_line and line <= note.end_line then
            table.insert(
                found,
                { type = "Note", comment = note.comment, time = note.timestamp }
            )
        end
    end

    -- Check history
    for i, snapshot in ipairs(session.history or {}) do
        for _, review in ipairs(snapshot.reviews or {}) do
            if matches_buf(review) and line >= review.start_line and line <= review.end_line then
                table.insert(found, {
                    type = "History (Snap " .. i .. ")",
                    comment = review.comment,
                    time = review.timestamp,
                })
            end
        end
    end

    if #found == 0 then
        mkreview.notify("No reviews or notes found for this line.\n", vim.log.levels.WARN)
        return
    end

    local msg = ""
    for _, f in ipairs(found) do
        msg = msg .. string.format("[%s] %s\n", f.type, f.comment)
    end
    mkreview.notify(msg)
end

--- Prompts the user for a self note and saves it.
--- @param opts? table Optional range {line1, line2}
function M.add_note(opts)
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

    vim.fn.sign_define("MkReviewNoteSign", {
        text = config.note_sign_text,
        texthl = config.note_sign_hl,
    })

    local function on_confirm(input)
        if not input or input == "" then
            mkreview.notify("Self note cancelled or empty.\n", vim.log.levels.WARN)
            return
        end

        state.add_note {
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
            vim.fn.sign_place(0, "MkReviewNoteGroup", "MkReviewNoteSign", bufnr, {
                lnum = line,
                priority = 11,
            })
        end

        local current_session = state.get_current_session()
        mkreview.notify(string.format("Self note added to session: %s\n", current_session.name))
    end

    if config.custom_ui then
        config.custom_ui({ prompt = "Self Note: ", is_edit = false }, on_confirm)
    else
        vim.ui.input({ prompt = "Self Note: " }, on_confirm)
    end
end

--- Removes note(s) for the current line or a range of lines.
--- @param opts? table Optional range {line1, line2}
function M.delete_note(opts)
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
    state.delete_notes(bufnr, start_line, end_line)
    M.refresh_signs()

    local mkreview = require("mkreview")
    mkreview.notify(string.format("Notes deleted in range %d-%d.\n", start_line, end_line))
end

--- Edits the note on the current cursor line.
function M.edit_note()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local note = state.get_note_at_line(bufnr, line)

    local mkreview = require("mkreview")
    if not note then
        mkreview.notify("No active note found on this line to edit.\n", vim.log.levels.WARN)
        return
    end

    M.preview_input({
        prompt = "Edit Self Note",
        initial_content = note.comment,
        is_edit = true,
    }, function(new_comment)
        if not new_comment or new_comment == "" then
            return
        end
        state.update_note(note, new_comment)
        mkreview.notify("Note updated.\n")
    end)
end

--- Displays the self note for the current cursor line in the preview window.
function M.view_note()
    local bufnr = vim.api.nvim_get_current_buf()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local note = state.get_note_at_line(bufnr, line)
    local mkreview = require("mkreview")

    if not note then
        mkreview.notify("No self note found on this line to view.\n", vim.log.levels.WARN)
        return
    end

    local buf_name = "[MkReview Note View]"
    vim.cmd("pedit " .. vim.fn.fnameescape(buf_name))
    vim.cmd("wincmd P")

    local pbufnr = vim.api.nvim_get_current_buf()
    local pwinnr = vim.api.nvim_get_current_win()

    vim.api.nvim_set_option_value("filetype", "markdown", { buf = pbufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = pbufnr })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = pbufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = pbufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = pbufnr })

    local header = string.format(
        "<!-- Note: %s:%d-%d | %s -->",
        vim.fn.fnamemodify(note.filename, ":t"),
        note.start_line,
        note.end_line,
        note.timestamp
    )
    local lines = { header, "" }
    for _, l in ipairs(vim.split(note.comment, "\n")) do
        table.insert(lines, l)
    end

    vim.api.nvim_buf_set_lines(pbufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = pbufnr })
    vim.api.nvim_set_option_value("modified", false, { buf = pbufnr })

    -- Easy exit mappings for preview window
    vim.keymap.set("n", "q", "<cmd>pclose<CR>", { buffer = pbufnr, nowait = true, silent = true })
    vim.keymap.set("n", "<Esc>", "<cmd>pclose<CR>", { buffer = pbufnr, nowait = true, silent = true })

    vim.api.nvim_win_set_cursor(pwinnr, { #lines > 2 and 3 or 1, 0 })
end

--- Lists notes in the location list for the current window.
function M.list_notes()
    local current_session = state.get_current_session()
    local notes = current_session.notes or {}
    local mkreview = require("mkreview")

    if #notes == 0 then
        mkreview.notify(
            string.format("No notes in session: %s\n", current_session.name),
            vim.log.levels.WARN
        )
        return
    end

    local loc_items = {}
    for _, note in ipairs(notes) do
        local display_comment = note.comment:gsub("\n", " ")
        table.insert(loc_items, {
            bufnr = (note.bufnr and vim.api.nvim_buf_is_valid(note.bufnr)) and note.bufnr or nil,
            filename = note.filename,
            lnum = note.start_line,
            col = note.start_col,
            text = display_comment,
        })
    end

    vim.fn.setloclist(0, loc_items, "r")
    vim.fn.setloclist(0, {}, "a", { title = string.format("MkReview Notes: %s", current_session.name) })
    vim.cmd("lopen")
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

    -- Prepare content
    local initial_lines = {}
    if opts.prompt then
        table.insert(initial_lines, "<!-- " .. opts.prompt .. " -->")
        table.insert(initial_lines, "")
    end

    if opts.initial_content then
        local content_lines = vim.split(opts.initial_content, "\n")
        for _, l in ipairs(content_lines) do
            table.insert(initial_lines, l)
        end
    else
        table.insert(initial_lines, "")
    end

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_lines)
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

    -- Position cursor: after the prompt if it exists, otherwise at the top
    local start_row = opts.prompt and 3 or 1
    vim.api.nvim_win_set_cursor(winnr, { start_row, 0 })

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

    -- Mode selection: Normal mode when editing, Insert mode when adding
    local is_edit = opts.is_edit
    if is_edit == nil then
        is_edit = (opts.initial_content ~= nil and opts.initial_content ~= "")
    end

    if is_edit then
        vim.cmd("stopinsert")
    else
        vim.cmd("startinsert")
    end
end

return M
