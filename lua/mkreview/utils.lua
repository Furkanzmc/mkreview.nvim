local M = {}

--- Gets the current selection range.
--- @return table
function M.get_selection()
    local mode = vim.fn.mode()
    local start_line, start_col, end_line, end_col

    if mode:match("[vV]") then
        -- Visual mode range
        local start_pos = vim.fn.getpos("v")
        local end_pos = vim.fn.getpos(".")
        start_line = start_pos[2]
        start_col = start_pos[3]
        end_line = end_pos[2]
        end_col = end_pos[3]

        -- Ensure start is before end
        if start_line > end_line or (start_line == end_line and start_col > end_col) then
            start_line, end_line = end_line, start_line
            start_col, end_col = end_col, start_col
        end
    else
        -- Normal mode (current line)
        local pos = vim.fn.getpos(".")
        start_line = pos[2]
        end_line = pos[2]
        start_col = 1
        end_col = #vim.fn.getline(".")
    end

    return {
        start_line = start_line,
        start_col = start_col,
        end_line = end_line,
        end_col = end_col,
    }
end

return M
