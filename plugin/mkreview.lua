-- plugin/mkreview.lua

-- Define user commands
vim.api.nvim_create_user_command("MkreviewAdd", function()
    require("mkreview.ui").add_review()
end, { range = true, desc = "Add a review for the current selection" })

vim.api.nvim_create_user_command("MkreviewShow", function()
    require("mkreview.ui").show_at_cursor()
end, { desc = "Show review(s) for the current line" })

vim.api.nvim_create_user_command("MkreviewDump", function()
    require("mkreview.export").dump()
end, { desc = "Dump the review session to JSON" })

vim.api.nvim_create_user_command("MkreviewList", function()
    require("mkreview.ui").list_reviews()
end, { desc = "List active reviews in current session" })

vim.api.nvim_create_user_command("MkreviewHistory", function()
    require("mkreview.ui").list_history()
end, { desc = "List historical snapshots in current session" })

vim.api.nvim_create_user_command("MkreviewSessionNew", function()
    require("mkreview.ui").new_session()
end, { desc = "Create and switch to a new review session" })

vim.api.nvim_create_user_command("MkreviewSessionList", function()
    require("mkreview.ui").list_sessions()
end, { desc = "List all review sessions and switch" })

vim.api.nvim_create_user_command("MkreviewClear", function()
    require("mkreview.state").clear_current_active()
    vim.fn.sign_unplace("MkReviewGroup")
    require("mkreview").notify("Current active reviews cleared.")
end, { desc = "Clear active reviews in the current session" })
