# mkreview.nvim

> [!IMPORTANT]
> This plugin was autonomously developed by **Gemini CLI** (an AI assistant).

`mkreview.nvim` is a Neovim plugin designed to help you interactively create code reviews that can be exported as JSON for LLM processing.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "your-username/mkreview.nvim",
    config = function()
        require("mkreview").setup()
    end
}
```

## Usage

1. **Add a Review**:
   - In **Normal Mode**, run `:MkReviewAdd` to add a review for the current line.
   - In **Visual Mode**, select a range and run `:MkReviewAdd`.
   - Enter your comment in the prompt.
   - A `»` sign will appear in the sign column.

2. **Show Review at Cursor**:
   - Run `:MkReviewShow` to see the review(s) for the current line in a notification.
   - This works for both active reviews and historical snapshots.

3. **List and Jump**:
   - Run `:MkReviewList` to see active reviews in the current session.
   - Run `:MkReviewHistory` to browse and jump to reviews from past dumps (the stack).

4. **Session Management**:
   - Run `:MkReviewSessionNew` to start a fresh session.
   - Run `:MkReviewSessionList` to switch between existing sessions.
   - Gutter signs automatically refresh to show only **active** reviews.

5. **Dump to JSON (The Stack)**:
   - Run `:MkReviewDump`.
   - A vertical split opens with a scratch buffer containing the JSON data.
   - **GitHub Integration**: Inside this scratch buffer, you can run the buffer-local command `:MkReviewToGithub`. This opens a *second* buffer with the formatted payload.
   - **Publish**: In the GitHub payload buffer, run `:make <PR_NUMBER>` (e.g., `:make 123`) to publish the review via `gh api`.
   - These reviews are then "pushed" to the session history stack, and the active list is cleared (along with gutter signs).
   - You can immediately start a new review round within the same session.

6. **Clear Session**:
   - Run `:MkReviewClear` to reset the active reviews and remove signs.

## Configuration

You can customize the plugin in `setup`:

```lua
require("mkreview").setup({
    sign_text = "»",
    sign_hl = "DiagnosticSignInfo",
    export_filename = ".mkreview.json",
    -- Custom UI for review comments
    custom_ui = nil,
    -- Custom UI for listing reviews
    custom_list_ui = nil,
})
```

## Keybindings (Example)

```lua
vim.keymap.set({"n", "v"}, "<leader>ra", ":MkReviewAdd<CR>", { desc = "Add Review" })
vim.keymap.set("n", "<leader>rs", ":MkReviewShow<CR>", { desc = "Show Review" })
vim.keymap.set("n", "<leader>rl", ":MkReviewList<CR>", { desc = "List Reviews" })
vim.keymap.set("n", "<leader>rd", ":MkReviewDump<CR>", { desc = "Dump Reviews" })
vim.keymap.set("n", "<leader>rc", ":MkReviewClear<CR>", { desc = "Clear Reviews" })
```
