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
    vim.api.nvim_buf_set_option(gh_bufnr, "swapfile", false)
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

        -- Create a buffer for the GitHub payload
        local gh_bufnr = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_option(gh_bufnr, "bufhidden", "wipe")
        vim.api.nvim_buf_set_option(gh_bufnr, "swapfile", false)
        vim.api.nvim_buf_set_option(gh_bufnr, "filetype", "json")

        -- Assign a unique temporary path as the buffer name
        local tmp_name = vim.fn.tempname() .. "_gh_review.json"
        vim.api.nvim_buf_set_name(gh_bufnr, tmp_name)

        vim.api.nvim_buf_set_lines(gh_bufnr, 0, -1, false, vim.split(encoded, "\n"))

        -- Add buffer-local publishing command
        vim.api.nvim_buf_create_user_command(gh_bufnr, "MkReviewPublishToGitHub", function(opts)
            local current_session = state.get_current_session()
            local pr_number = (opts.args ~= "") and opts.args or current_session.github_pr_number
            local review_id = current_session.github_review_id

            if not pr_number or pr_number == "" then
                mkreview.notify("PR number required. Usage: :MkReviewPublishToGitHub <PR_NUMBER>", vim.log.levels.ERROR)
                return
            end

            -- Ensure we have saved the buffer to the temp file
            vim.cmd("write!")

            local api_cmd
            if review_id then
                -- Append mode: expects comments array
                api_cmd = string.format(
                    "cat %s | jq '.comments // .' | gh api repos/:owner/:repo/pulls/%s/reviews/%s/comments --input -",
                    tmp_name, pr_number, review_id
                )
            else
                -- New review mode
                api_cmd = string.format(
                    "gh api repos/:owner/:repo/pulls/%s/reviews --input %s",
                    pr_number, tmp_name
                )
            end

            local output = vim.fn.system(api_cmd)
            local res_success, res_decoded = pcall(vim.fn.json_decode, output)
            
            if res_success then
                if res_decoded.id then
                    state.set_github_metadata(pr_number, res_decoded.id)
                    mkreview.notify(string.format("Published to PR #%s (Review ID: %s)", pr_number, res_decoded.id))
                else
                    mkreview.notify("Successfully published comments to existing review.")
                end
            else
                mkreview.notify("Failed to parse GitHub response: " .. output, vim.log.levels.ERROR)
            end
        end, { nargs = "?", desc = "Publish review payload to GitHub (caches PR# and Review ID)" })

        -- Open the new buffer in a split
        vim.api.nvim_command("vsplit")
        vim.api.nvim_win_set_buf(0, gh_bufnr)

        -- Re-format if formatprg is set
        local inner_formatprg = vim.api.nvim_buf_get_option(gh_bufnr, "formatprg")
        if inner_formatprg ~= "" then
            vim.api.nvim_command("normal! gqG")
        end

        local current_session = state.get_current_session()
        if current_session.github_review_id then
            mkreview.notify(string.format("Ready to append to PR #%s (Review: %s). Run :MkReviewPublishToGitHub", 
                current_session.github_pr_number, current_session.github_review_id))
        else
            mkreview.notify("GitHub payload created. Run ':MkReviewPublishToGitHub <PR_NUMBER>' to create a Draft review.")
        end
    end, { desc = "Transform current JSON to GitHub API format and prepare for publishing" })

    -- Format if formatprg is set
    local formatprg = vim.api.nvim_buf_get_option(bufnr, "formatprg")
    if formatprg ~= "" then
        vim.api.nvim_command("normal! gqG")
    end

    mkreview.notify("Reviews dumped to scratch buffer.")
end

return M
