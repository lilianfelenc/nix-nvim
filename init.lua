-- =========================
-- BASIC SETTINGS
-- =========================
vim.cmd("syntax on")
vim.cmd("filetype plugin indent on")
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 200
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.path:append("**")
-- :diffsplit always splits vertically
vim.opt.diffopt:append("vertical")
vim.cmd("colorscheme carbonfox")

-- terminal escape
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>")
vim.g.mapleader = " "

-- d = delete (no yank), <leader>d = cut (goes to register)
vim.keymap.set({"n","v"}, "d",           '"_d',          { desc = "Delete no yank" })
vim.keymap.set("n",       "dd",          '"_dd',         { desc = "Delete line no yank" })
vim.keymap.set({"n","v"}, "<leader>d",   '"+d',          { desc = "Cut to clipboard" })
vim.keymap.set("n",       "<leader>dd",  '"+dd',         { desc = "Cut line to clipboard" })

-- =========================
-- TREESITTER
-- =========================
require("nvim-treesitter").setup()

local ts_langs = { "c", "cpp", "python", "bash", "json", "yaml", "lua" }

vim.api.nvim_create_autocmd("FileType", {
  pattern = ts_langs,
  callback = function()
    vim.treesitter.start()
  end,
})

-- key map page
require("hk")

-- =========================
-- LUALINE
-- =========================
require("lualine").setup()

-- =========================
-- TELESCOPE
-- =========================
local telescope = require("telescope")
telescope.setup({})

-- File/buffer navigation
vim.keymap.set("n", "<leader>r",  ":Telescope oldfiles<CR>",          { desc = "Recent files" })
vim.keymap.set("n", "<leader>b",  ":Telescope buffers<CR>",         { desc = "Buffers" })

-- Telescope (already in your config, updated to use leader)
vim.keymap.set("n", "<leader>ff", require("telescope.builtin").find_files,  { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", require("telescope.builtin").live_grep,   { desc = "Live grep" })

-- =========================
-- LSP CONFIG
-- =========================
vim.lsp.config("lua_ls", {
  settings = {
    Lua = { diagnostics = { globals = { "vim" } } },
  },
})

vim.lsp.config("vhdl_ls", {
  -- project root = dir with vhdl_ls.toml, else git root, else the file's dir
  root_dir = function(bufnr, on_dir)
    local root = vim.fs.root(bufnr, { "vhdl_ls.toml", ".vhdl_ls.toml", ".git" })
      or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    on_dir(root)
  end,
})

vim.lsp.config('svlangserver', {
  settings = {
    systemverilog = {
      includeIndexing = { '*.{v,vh,sv,svh}', '**/*.{v,vh,sv,svh}' },
      launchConfiguration = "verilator -sv --lint-only -Wall",
    }
  }
})

vim.lsp.enable({
  "clangd",
  "pyright",
  "bashls",
  "yamlls",
  "lua_ls",
  "vhdl_ls",
  "svlangserver",
})

vim.keymap.set("n", "gd", vim.lsp.buf.definition)
vim.keymap.set("n", "gr", vim.lsp.buf.references)
vim.keymap.set("n", "K", vim.lsp.buf.hover)
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)
vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end)
vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end)

-- =========================
-- AUTOCOMPLETE (CMP)
-- =========================
local cmp = require("cmp")
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ["<Tab>"] = cmp.mapping.confirm({ select = true }),
    ["<C-Space>"] = cmp.mapping.complete(),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "buffer" },
    { name = "path" },
  },
})

-- =========================
-- DTS SUPPORT (Embedded)
-- =========================
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.dts", "*.dtsi" },
  callback = function()
    vim.bo.filetype = "dts"
  end,
})

-- Keep nvim's cwd in sync with the shell running in the terminal buffer.
-- Also runs when opening the cmdline (`:`), so `:e`, `:!`, etc. use the
-- terminal's current directory even if the shell cd'd since the last event.
local function sync_cwd_from_terminal()
  if vim.bo.buftype ~= 'terminal' then return end
  local pid = vim.b.terminal_job_pid
  if not pid then return end
  local cwd = vim.uv.fs_readlink('/proc/' .. pid .. '/cwd')
  if cwd and vim.fn.isdirectory(cwd) == 1 and cwd ~= vim.fn.getcwd() then
    vim.cmd.cd(vim.fn.fnameescape(cwd))
  end
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufLeave', 'WinEnter', 'TermEnter', 'TermLeave', 'CmdlineEnter' }, {
  desc = 'cd to terminal cwd',
  callback = sync_cwd_from_terminal,
})

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "bitbake" },
  callback = function(args)
    vim.lsp.start({
      name = "bitbake",
      cmd = { "language-server-bitbake", "--stdio" },
      root_dir = vim.fs.root(args.buf, { "bblayers.conf", ".git" }) or vim.fn.getcwd(),
    })
  end,
})

-- =========================
-- oelint-adv with nvim-lint
-- =========================
local lint = require('lint')

lint.linters.oelint_adv = {
  cmd = 'oelint-adv',
  stdin = false,
  args = {
    '--quiet',
    '--messageformat={path}:{line}:{severity}:{id}:{msg}',
  },
  env = {
    ["NO_COLOR"] = "1",
    ["HOME"] = os.getenv("HOME"),
  },
  ignore_exitcode = true,
  stream = 'stderr',
  parser = require('lint.parser').from_pattern(
    '([^:]+):(%d+):(%a+):([^:]+):(.+)',
    { 'file', 'lnum', 'severity', 'code', 'message' },
    {
      ['error'] = vim.diagnostic.severity.ERROR,
      ['warning'] = vim.diagnostic.severity.WARN,
      ['info'] = vim.diagnostic.severity.INFO,
    },
    { ['source'] = 'oelint-adv' }
  ),
}

lint.linters_by_ft = lint.linters_by_ft or {}
lint.linters_by_ft.bitbake = { 'oelint_adv' }

vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
  pattern = { "*.bb", "*.bbappend", "*.bbclass", "*.inc" },
  callback = function()
    lint.try_lint()
  end,
})
