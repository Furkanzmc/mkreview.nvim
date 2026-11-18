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

4. **Self Notes (Loclist Navigation & Preview)**:
   - Run `:MkReviewNoteAdd` in Normal or Visual mode to add a reviewer self-note.
   - Self-notes appear with an `N` sign in the gutter (by default).
   - Run `:MkReviewNotes` to display all self-notes in the location list (`loclist`) and easily jump between them to review your thoughts later.
   - Run `:MkReviewNoteView` to read the full note on the current line in a markdown preview window (close with `q` or `<Esc>`).
   - Run `:MkReviewNoteEdit` or `:MkReviewNoteDelete` to modify or remove notes.

5. **Session Management**:
   - Run `:MkReviewSessionNew` to start a fresh session.
   - Run `:MkReviewSessionList` to switch between existing sessions.
   - Gutter signs automatically refresh to show only **active** reviews and notes.

6. **Dump and Publish**:
   - Run `:MkReviewDump`.
   - A vertical split opens with a scratch buffer containing GitHub-compatible JSON.
   - **First Push**: Run `:MkReviewPublishToGitHub <PR_NUMBER>` (e.g., `:MkReviewPublishToGitHub 123`).
     - This creates a **Draft** review and **automatically caches** the Review ID in your current session.
   - **Subsequent Pushes**: After adding more reviews and dumping again, just run `:MkReviewPublishToGitHub`.
     - The plugin will use the cached PR number and Review ID to append comments to the *existing* draft.

7. **Save & Load Review JSON Sessions**:
   - Run `:MkReviewDumpSession` to export the complete session (reviews, self notes, history, PR metadata) into a new JSON buffer. Use `:w <filepath>` to save it wherever you want.
   - In any new session or Neovim instance, run `:MkReviewLoad <filepath> [session_name]` to load either MkReview native session JSON or GitHub review JSON (`{ body, comments: [...] }` or array of comments).
   - Alternatively, use `:MkReviewImportGitHub <filepath> [session_name]` to explicitly import GitHub-format JSON. Restores all reviews, paths, and gutter signs.

8. **Archive (Batching)**:
   - Run `:MkReviewPush` to move active reviews to history and clear gutter signs.

9. **Reset / New PR**:
   - Run `:MkReviewClear` to clear active reviews and **wipe the cached GitHub metadata** (PR# and Review ID).


## Configuration

You can customize the plugin in `setup`:

```lua
require("mkreview").setup({
    sign_text = "❯",
    sign_hl = "DiagnosticSignInfo",
    note_sign_text = "N",
    note_sign_hl = "DiagnosticSignHint",
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
vim.keymap.set({"n", "v"}, "<leader>rn", ":MkReviewNoteAdd<CR>", { desc = "Add Self Note" })
vim.keymap.set("n", "<leader>rN", ":MkReviewNotes<CR>", { desc = "List Notes (Loclist)" })
vim.keymap.set("n", "<leader>rv", ":MkReviewNoteView<CR>", { desc = "View Note in Preview" })
vim.keymap.set("n", "<leader>rs", ":MkReviewShow<CR>", { desc = "Show Review / Note" })
vim.keymap.set("n", "<leader>rl", ":MkReviewList<CR>", { desc = "List Reviews" })
vim.keymap.set("n", "<leader>rd", ":MkReviewDump<CR>", { desc = "Dump GitHub Payload" })
vim.keymap.set("n", "<leader>rD", ":MkReviewDumpSession<CR>", { desc = "Dump Session JSON" })
vim.keymap.set("n", "<leader>rc", ":MkReviewClear<CR>", { desc = "Clear Reviews" })
```
