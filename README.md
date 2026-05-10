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
   - A `❯` sign will appear in the sign column.

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

5. **Dump and Publish**:
   - Run `:MkReviewDump`.
   - A vertical split opens with a scratch buffer containing GitHub-compatible JSON.
   - **First Push**: Run `:MkReviewPublishToGitHub <PR_NUMBER>` (e.g., `:MkReviewPublishToGitHub 123`).
     - This creates a **Draft** review and **automatically caches** the Review ID in your current session.
   - **Subsequent Pushes**: After adding more reviews and dumping again, just run `:MkReviewPublishToGitHub`.
     - The plugin will use the cached PR number and Review ID to append comments to the *existing* draft.

6. **Archive (Batching)**:
   - Run `:MkReviewPush` to move active reviews to history and clear gutter signs.

7. **Reset / New PR**:
   - Run `:MkReviewClear` to clear active reviews and **wipe the cached GitHub metadata** (PR# and Review ID).


## Configuration

You can customize the plugin in `setup`:

```lua
require("mkreview").setup({
    sign_text = "❯",
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
