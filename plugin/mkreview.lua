-- plugin/mkreview.lua

-- Define user commands
vim.api.nvim_create_user_command("MkReviewAdd", function()
    require("mkreview.ui").add_review()
end, { range = true, desc = "Add a review for the current selection" })

vim.api.nvim_create_user_command("MkReviewShow", function()
    require("mkreview.ui").show_at_cursor()
end, { desc = "Show review(s) for the current line" })

vim.api.nvim_create_user_command("MkReviewDump", function()
    require("mkreview.export").dump()
end, { desc = "Dump the review session to JSON" })

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
