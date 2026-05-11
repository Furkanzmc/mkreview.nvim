local state = require("mkreview.state")
local config = require("mkreview").config
local M = {}

--- Dumps the current session's active reviews to a scratch buffer in GitHub-compatible format.
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

    -- Generate GitHub-compatible payload directly
    local root = vim.fn.getcwd() .. "/"
    local github_format = {
        body = string.format("Review session: %s", session.name or "Untitled"),
        comments = {},
    }

    for _, review in ipairs(reviews) do
        local relative_path = review.filename:gsub("^" .. vim.pesc(root), "")
        local comment = {
            path = relative_path,
            line = review.end_line,
            body = review.comment,
            side = "RIGHT",
        }
        -- Add multi-line range if applicable
        if review.start_line < review.end_line then
            comment.start_line = review.start_line
            comment.start_side = "RIGHT"
        end
        table.insert(github_format.comments, comment)
    end

    local json_data = vim.fn.json_encode(github_format)
    local lines = vim.split(json_data, "\n")

    -- Create a scratch buffer
    local bufnr = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "json", { buf = bufnr })

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

    -- Assign a unique temporary path for publishing
    local tmp_name = vim.fn.tempname() .. "_gh_review.json"

    -- Add buffer-local publishing command
    vim.api.nvim_buf_create_user_command(bufnr, "MkReviewPublishToGitHub", function(opts)
        local current_session = state.get_current_session()
        local pr_number = (opts.args ~= "") and opts.args or current_session.github_pr_number
        local review_node_id = current_session.github_review_node_id
        local commit_id = current_session.github_commit_id
        local pr_node_id = current_session.github_pr_node_id

        if not pr_number or pr_number == "" then
            mkreview.notify(
                "PR number required. Usage: :MkReviewPublishToGitHub <PR_NUMBER>",
                vim.log.levels.ERROR
            )
            return
        end

        -- Ensure buffer is saved to the temp file for API use
        local content = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
        local f = io.open(tmp_name, "w")
        if f then
            f:write(content)
            f:close()
            vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        else
            mkreview.notify("Failed to write temporary file for publishing.", vim.log.levels.ERROR)
            return
        end

        if review_node_id and commit_id then
            -- Append mode: Use modern GraphQL Threading
            if not pr_node_id then
                local fetch_cmd = string.format("gh pr view %s --json id -q .id", pr_number)
                pr_node_id = vim.fn.system(fetch_cmd):gsub("\n", "")
                state.set_github_metadata(pr_number, nil, nil, pr_node_id)
            end

            mkreview.notify(string.format("Appending comments to Review ID: %s", review_node_id))

            local decoded_payload = vim.fn.json_decode(content)
            local comments = decoded_payload.comments or decoded_payload

            local success_count = 0
            for _, comment in ipairs(comments) do
                local query = [[
                    mutation($prId: ID!, $reviewId: ID!, $body: String!, $path: String!, $line: Int!, $side: DiffSide!, $startLine: Int, $startSide: DiffSide) {
                        addPullRequestReviewThread(input: {
                            pullRequestId: $prId,
                            pullRequestReviewId: $reviewId,
                            body: $body,
                            path: $path,
                            line: $line,
                            side: $side,
                            startLine: $startLine,
                            startSide: $startSide
                        }) {
                            thread { id }
                        }
                    }
                ]]

                local extra_args = ""
                if comment.start_line then
                    extra_args = string.format(
                        "-F startLine=%d -f startSide='%s'",
                        tonumber(comment.start_line),
                        comment.start_side or "RIGHT"
                    )
                end

                local api_cmd = string.format(
                    "gh api graphql -F query='%s' -f prId='%s' -f reviewId='%s' -f body='%s' -f path='%s' -F line=%d -f side='%s' %s",
                    query:gsub("\n", " "),
                    pr_node_id,
                    review_node_id,
                    comment.body:gsub("'", "'\\''"),
                    comment.path,
                    tonumber(comment.line),
                    comment.side or "RIGHT",
                    extra_args
                )

                local output = vim.fn.system(api_cmd)
                if vim.v.shell_error == 0 then
                    success_count = success_count + 1
                else
                    mkreview.notify(
                        "Failed to post GraphQL comment: " .. output,
                        vim.log.levels.ERROR
                    )
                end
            end
            mkreview.notify(
                string.format(
                    "Successfully appended %d comments to PR #%s.",
                    success_count,
                    pr_number
                )
            )
        else
            -- New review mode (REST API)
            local api_cmd = string.format(
                "gh api repos/:owner/:repo/pulls/%s/reviews --input %s",
                pr_number,
                tmp_name
            )
            local output = vim.fn.system(api_cmd)
            local res_success, res_decoded = pcall(vim.fn.json_decode, output)

            if res_success and res_decoded.node_id then
                state.set_github_metadata(pr_number, res_decoded.node_id, res_decoded.commit_id)
                mkreview.notify(
                    string.format(
                        "Created Draft Review on PR #%s (ID: %s)",
                        pr_number,
                        res_decoded.node_id
                    )
                )
            else
                mkreview.notify("Failed to create review: " .. output, vim.log.levels.ERROR)
            end
        end
    end, { nargs = "?", desc = "Publish review payload to GitHub" })

    -- Open the buffer in a split
    vim.api.nvim_command("vsplit")
    vim.api.nvim_win_set_buf(0, bufnr)

    -- Format if formatprg is set
    local formatprg = vim.api.nvim_get_option_value("formatprg", { buf = bufnr })
    if formatprg ~= "" then
        vim.api.nvim_command("normal! gqG")
    end

    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

    local current_session = state.get_current_session()
    if current_session.github_review_node_id then
        mkreview.notify(
            string.format(
                "Dumped to GitHub format. Ready to append to PR #%s. Run :MkReviewPublishToGitHub",
                current_session.github_pr_number
            )
        )
    else
        mkreview.notify(
            "Dumped to GitHub format. Run ':MkReviewPublishToGitHub <PR_NUMBER>' to create a Draft review."
        )
    end
end

return M
