-- plugin/mkreview.lua

-- Define user commands
vim.api.nvim_create_user_command("MkReviewAdd", function(opts)
    require("mkreview.ui").add_review(opts)
end, { range = true, desc = "Add a review for the current selection" })

vim.api.nvim_create_user_command("MkReviewDelete", function(opts)
    require("mkreview.ui").delete_review(opts)
end, { range = true, desc = "Delete review(s) for the current line or range" })

vim.api.nvim_create_user_command("MkReviewEdit", function()
    require("mkreview.ui").edit_review()
end, { desc = "Edit the review for the current line" })

vim.api.nvim_create_user_command("MkReviewShow", function()
    require("mkreview.ui").show_at_cursor()
end, { desc = "Show review(s) for the current line" })

vim.api.nvim_create_user_command("MkReviewDump", function()
    require("mkreview.export").dump()
end, { desc = "Dump the review session to JSON" })

vim.api.nvim_create_user_command("MkReviewDumpSession", function()
    require("mkreview.export").dump_session()
end, { desc = "Dump the full review session state to a new JSON buffer" })

vim.api.nvim_create_user_command("MkReviewLoad", function(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local filepath = args[1]
    local session_name = args[2]
    require("mkreview.export").load_session(filepath, session_name)
end, { nargs = "*", complete = "file", desc = "Load a review session JSON file (MkReview or GitHub format) into a new session" })

vim.api.nvim_create_user_command("MkReviewImportGitHub", function(opts)
    local args = vim.split(opts.args, "%s+", { trimempty = true })
    local filepath = args[1]
    local session_name = args[2]
    require("mkreview.export").load_session(filepath, session_name)
end, { nargs = "*", complete = "file", desc = "Import a GitHub-format review JSON file into a new session" })

vim.api.nvim_create_user_command("MkReviewNoteAdd", function(opts)
    require("mkreview.ui").add_note(opts)
end, { range = true, desc = "Add a self note for the current selection or line" })

vim.api.nvim_create_user_command("MkReviewNotes", function()
    require("mkreview.ui").list_notes()
end, { desc = "Show self notes in the location list" })

vim.api.nvim_create_user_command("MkReviewNoteView", function()
    require("mkreview.ui").view_note()
end, { desc = "View the self note on the current line in the preview window" })

vim.api.nvim_create_user_command("MkReviewNoteDelete", function(opts)
    require("mkreview.ui").delete_note(opts)
end, { range = true, desc = "Delete self note(s) for the current line or range" })

vim.api.nvim_create_user_command("MkReviewNoteEdit", function()
    require("mkreview.ui").edit_note()
end, { desc = "Edit the self note for the current line" })

vim.api.nvim_create_user_command("MkReviewList", function()
    require("mkreview.ui").list_reviews()
end, { desc = "List active reviews in current session" })

vim.api.nvim_create_user_command("MkReviewHistory", function()
    require("mkreview.ui").list_history()
end, { desc = "List historical snapshots in current session" })

vim.api.nvim_create_user_command("MkReviewSessionNew", function()
    require("mkreview.ui").new_session()
end, { desc = "Create and switch to a new review session" })

vim.api.nvim_create_user_command("MkReviewSessionList", function()
    require("mkreview.ui").list_sessions()
end, { desc = "List all review sessions and switch" })

vim.api.nvim_create_user_command("MkReviewPush", function()
    require("mkreview.state").push_current_to_history()
    vim.fn.sign_unplace("MkReviewGroup")
    require("mkreview").notify("Active reviews moved to history.")
end, { desc = "Archive active reviews to history stack" })

vim.api.nvim_create_user_command("MkReviewClear", function()
    require("mkreview.state").clear_current_active()
    vim.fn.sign_unplace("MkReviewGroup")
    require("mkreview").notify("Current active reviews cleared.")
end, { desc = "Clear active reviews in the current session" })

-- Automatically refresh signs when opening or switching to buffers
local augroup = vim.api.nvim_create_augroup("MkReviewAutoSigns", { clear = true })
vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = augroup,
    callback = function()
        require("mkreview.ui").refresh_signs()
    end,
})
