local common = require("common")

--------------------------------------------
-- General setup
--------------------------------------------

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.scrolljump = 5
vim.opt.scrolloff = 3
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.ttimeoutlen = 1
vim.opt.updatetime = 100
vim.opt.mouse = "nv"
vim.opt.showmode = false
vim.opt.laststatus = 2
vim.opt.linebreak = true
vim.opt.number = true
vim.opt.numberwidth = 3
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.ignorecase = true
vim.opt.backup = true
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.backupdir = "/tmp"
vim.opt.dir = "/tmp"
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.softtabstop = 4
vim.opt.tabstop = 4
vim.opt.foldenable = false
vim.opt.spell = false

-- don't automatically select the first result in suggestions
vim.cmd("set completeopt+=noselect")

require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = true },
  change_detection = {
      enabled = true,
      notify = false,
  },
})

--------------------------------------------
-- Requires
--------------------------------------------

require("mappings")
require("auto_cmd")

--------------------------------------------
-- Misc plugin setup
--------------------------------------------

---- https://github.com/yetone/avante.nvim?tab=readme-ov-file#default-setup-configuration
--require('avante').setup({
--  provider = "claude", -- The provider used in Aider mode or in the planning phase of Cursor Planning Mode
--  ---@alias Mode "agentic" | "legacy"
--  mode = "agentic", -- The default mode for interaction. "agentic" uses tools to automatically generate code, "legacy" uses the old planning method to generate code.
--  -- WARNING: Since auto-suggestions are a high-frequency operation and therefore expensive,
--  -- currently designating it as `copilot` provider is dangerous because: https://github.com/yetone/avante.nvim/issues/1048
--  -- Of course, you can reduce the request frequency by increasing `suggestion.debounce`.
--  auto_suggestions_provider = "claude",
--  providers = {
--    claude = {
--      endpoint = "https://api.anthropic.com",
--      model = "claude-sonnet-4-20250514",
--      extra_request_body = {
--        temperature = 0.75,
--        max_tokens = 4096,
--      },
--    },
--  },
--  dual_boost = {
--    enabled = false,
--  },
--  behaviour = {
--    auto_suggestions = false, -- Experimental stage
--    auto_set_highlight_group = true,
--    auto_set_keymaps = true,
--    auto_apply_diff_after_generation = false,
--    support_paste_from_clipboard = false,
--    minimize_diff = true, -- Whether to remove unchanged lines when applying a code block
--    enable_token_counting = true, -- Whether to enable token counting. Default to true.
--    auto_approve_tool_permissions = false, -- Default: show permission prompts for all tools
--  },
--  mappings = {
--    diff = {
--      ours = "co",
--      theirs = "ct",
--      all_theirs = "ca",
--      both = "cb",
--      cursor = "cc",
--      next = "]x",
--      prev = "[x",
--    },
--    suggestion = {
--      accept = "<M-l>",
--      next = "<M-]>",
--      prev = "<M-[>",
--      dismiss = "<C-]>",
--    },
--    jump = {
--      next = "]]",
--      prev = "[[",
--    },
--    submit = {
--      normal = "<CR>",
--      insert = "<C-s>",
--    },
--    cancel = {
--      normal = { "<C-c>", "<Esc>", "q" },
--      insert = { "<C-c>" },
--    },
--    sidebar = {
--      apply_all = "A",
--      apply_cursor = "a",
--      retry_user_request = "r",
--      edit_user_request = "e",
--      switch_windows = "<Tab>",
--      reverse_switch_windows = "<S-Tab>",
--      remove_file = "d",
--      add_file = "@",
--      close = { "<Esc>", "q" },
--      close_from_input = nil, -- e.g., { normal = "<Esc>", insert = "<C-d>" }
--    },
--  },
--  hints = { enabled = true },
--  windows = {
--    ---@type "right" | "left" | "top" | "bottom"
--    position = "right", -- the position of the sidebar
--    wrap = true, -- similar to vim.o.wrap
--    width = 30, -- default % based on available width
--    sidebar_header = {
--      enabled = true, -- true, false to enable/disable the header
--      align = "center", -- left, center, right for title
--      rounded = true,
--    },
--    input = {
--      prefix = "> ",
--      height = 8, -- Height of the input window in vertical layout
--    },
--    edit = {
--      border = "rounded",
--      start_insert = true, -- Start insert mode when opening the edit window
--    },
--    ask = {
--      floating = false, -- Open the 'AvanteAsk' prompt in a floating window
--      start_insert = true, -- Start insert mode when opening the ask window
--      border = "rounded",
--      ---@type "ours" | "theirs"
--      focus_on_apply = "ours", -- which diff to focus after applying
--    },
--  },
--  highlights = {
--    ---@type AvanteConflictHighlights
--    diff = {
--      current = "DiffText",
--      incoming = "DiffAdd",
--    },
--  },
--  --- @class AvanteConflictUserConfig
--  diff = {
--    autojump = true,
--    ---@type string | fun(): any
--    list_opener = "copen",
--    --- Override the 'timeoutlen' setting while hovering over a diff (see :help timeoutlen).
--    --- Helps to avoid entering operator-pending mode with diff mappings starting with `c`.
--    --- Disable by setting to -1.
--    override_timeoutlen = 500,
--  },
--  suggestion = {
--    debounce = 600,
--    throttle = 600,
--  },
--})
