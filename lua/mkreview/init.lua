--- @brief This plugin was autonomously developed by Gemini CLI (an AI assistant).
local M = {}

M.config = {
    sign_text = "❯",
    sign_hl = "DiagnosticSignInfo",
    export_filename = ".mkreview.json",
    --- @type function? A function that takes {prompt, callback} and handles input. By default uses a preview buffer.
    custom_ui = function(opts, callback)
        require("mkreview.ui").preview_input(opts, callback)
    end,
    --- @type function? A function that takes {items, prompt, callback} and handles selection. If nil, uses vim.ui.select.
    custom_list_ui = nil,
}

--- Initializes the plugin with optional user configuration.
--- @param opts? table Configuration options:
---   - sign_text (string): Character to display in sign column (default: "❯")
---   - sign_hl (string): Highlight group for the sign (default: "DiagnosticSignInfo")
---   - export_filename (string): Default filename for JSON exports (default: ".mkreview.json")
---   - custom_ui (function): Custom function for review input
---   - custom_list_ui (function): Custom function for listing reviews
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    -- Define the sign used for reviews
    vim.fn.sign_define("MkReviewSign", {
        text = M.config.sign_text,
        texthl = M.config.sign_hl,
    })
end

--- Notify helper
--- @param msg string
--- @param level? number
function M.notify(msg, level)
    vim.notify(msg, level or vim.log.levels.INFO, { title = "mkreview.nvim" })
end

return M
