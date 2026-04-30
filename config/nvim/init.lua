--[[

=====================================================================
==================== READ THIS BEFORE CONTINUING ====================
=====================================================================
========                                    .-----.          ========
========         .----------------------.   | === |          ========
========         |.-""""""""""""""""""-.|   |-----|          ========
========         ||                    ||   | === |          ========
========         ||   KICKSTART.NVIM   ||   |-----|          ========
========         ||                    ||   | === |          ========
========         ||                    ||   |-----|          ========
========         ||:Tutor              ||   |:::::|          ========
========         |'-..................-'|   |____o|          ========
========         `"")----------------(""`   ___________      ========
========        /::::::::::|  |::::::::::\  \ no mouse \     ========
========       /:::========|  |==hjkl==:::\  \ required \    ========
========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
========                                                     ========
=====================================================================
=====================================================================

What is Kickstart?

  Kickstart.nvim is *not* a distribution.

  Kickstart.nvim is a starting point for your own configuration.
    The goal is that you can read every line of code, top-to-bottom, understand
    what your configuration is doing, and modify it to suit your needs.

    Once you've done that, you can start exploring, configuring and tinkering to
    make Neovim your own! That might mean leaving Kickstart just the way it is for a while
    or immediately breaking it into modular pieces. It's up to you!

    If you don't know anything about Lua, I recommend taking some time to read through
    a guide. One possible example which will only take 10-15 minutes:
      - https://learnxinyminutes.com/docs/lua/

    After understanding a bit more about Lua, you can use `:help lua-guide` as a
    reference for how Neovim integrates Lua.
    - :help lua-guide
    - (or HTML version): https://neovim.io/doc/user/lua-guide.html

Kickstart Guide:

  TODO: The very first thing you should do is to run the command `:Tutor` in Neovim.

    If you don't know what this means, type the following:
      - <escape key>
      - :
      - Tutor
      - <enter key>

    (If you already know the Neovim basics, you can skip this step.)

  Once you've completed that, you can continue working through **AND READING** the rest
  of the kickstart init.lua.

  Next, run AND READ `:help`.
    This will open up a help window with some basic information
    about reading, navigating and searching the builtin help documentation.

    This should be the first place you go to look when you're stuck or confused
    with something. It's one of my favorite Neovim features.

    MOST IMPORTANTLY, we provide a keymap "<space>sh" to [s]earch the [h]elp documentation,
    which is very useful when you're not exactly sure of what you're looking for.

  I have left several `:help X` comments throughout the init.lua
    These are hints about where to find more information about the relevant settings,
    plugins or Neovim features used in Kickstart.

   NOTE: Look for lines like this

    Throughout the file. These are for you, the reader, to help you understand what is happening.
    Feel free to delete them once you know what you're doing, but they should serve as a guide
    for when you are first encountering a few different constructs in your Neovim config.

If you experience any errors while trying to install kickstart, run `:checkhealth` for more info.

I hope you enjoy your Neovim journey,
- TJ

P.S. You can delete this when you're done too. It's your config now! :)
--]]

-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are loaded (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = false

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.o.number = true
-- You can also add relative line numbers, to help with jumping.
--  Experiment for yourself to see if you like it!
-- vim.o.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.o.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)

-- Enable break indent
vim.o.breakindent = true

-- Use 4-space indentation by default
vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4

-- Enable undo/redo changes even after closing and reopening a file
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
--
--  Notice listchars is set using `vim.opt` instead of `vim.o`.
--  It is very similar to `vim.o` but offers an interface for conveniently interacting with tables.
--   See `:help lua-options`
--   and `:help lua-guide-options`
vim.o.list = true
vim.opt.listchars = { tab = '> ', trail = '.', nbsp = '_' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 3

-- Compute folds, but keep them open by default until explicitly closed.
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- if performing an operation that would fail due to unsaved changes in the buffer (like `:q`),
-- instead raise a dialog asking if you wish to save the current file(s)
-- See `:help 'confirm'`
vim.o.confirm = true

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic Config & Keymaps
-- See :help vim.diagnostic.Opts
vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },

  -- Can switch between these as you prefer
  virtual_text = true, -- Text shows up at the end of the line
  virtual_lines = false, -- Text shows up underneath the line, with virtual lines

  -- Auto open the float, so you can easily read the errors when jumping with `[d` and `]d`
  jump = { float = true },
}

vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set('t', '<C-h>', '<C-\\><C-n><C-w>h', { desc = 'Move focus to the left window' })
vim.keymap.set('t', '<C-l>', '<C-\\><C-n><C-w>l', { desc = 'Move focus to the right window' })
vim.keymap.set('t', '<C-j>', '<C-\\><C-n><C-w>j', { desc = 'Move focus to the lower window' })
vim.keymap.set('t', '<C-k>', '<C-\\><C-n><C-w>k', { desc = 'Move focus to the upper window' })
vim.keymap.set('t', '<C-w>h', '<C-\\><C-n><C-w>h', { desc = 'Move focus to the left window' })
vim.keymap.set('t', '<C-w>l', '<C-\\><C-n><C-w>l', { desc = 'Move focus to the right window' })
vim.keymap.set('t', '<C-w>j', '<C-\\><C-n><C-w>j', { desc = 'Move focus to the lower window' })
vim.keymap.set('t', '<C-w>k', '<C-\\><C-n><C-w>k', { desc = 'Move focus to the upper window' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

vim.filetype.add {
  extension = {
    m = 'mma',
    wl = 'mma',
  },
}

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'mma',
  group = vim.api.nvim_create_augroup('dotfiles-wolfram-filetype', { clear = true }),
  callback = function(event)
    vim.bo[event.buf].commentstring = '(*%s*)'
    -- The current Wolfram tree-sitter grammar is good enough for highlighting,
    -- but some real-world definitions still parse with errors and produce broken folds.
    -- Use indentation-based folding for mma buffers until the grammar improves.
    vim.wo.foldmethod = 'indent'
    vim.wo.foldexpr = '0'
    vim.keymap.set('n', '<leader>wd', '<cmd>WolframGotoDefinition<CR>', {
      buffer = event.buf,
      desc = 'Wolfram: goto definition',
    })
  end,
})

-- [[ REPL helpers ]]

local function ensure_slime_defaults()
  vim.g.slime_target = 'neovim'
  vim.g.slime_suggest_default = 1
  vim.g.slime_menu_config = 0
  vim.g.slime_paste_file = '/tmp/.slime_paste'
  vim.g.slime_python_ipython = 1
  vim.g.slime_mma_paste_index = vim.g.slime_mma_paste_index or 0
  vim.g.slime_asir_paste_index = vim.g.slime_asir_paste_index or 0
end

local function define_repl_escape_functions()
  vim.cmd([[
    function! _EscapeText_mma(text) abort
      let text = substitute(a:text, "\n*$", "", "")
      if count(text, "\n") >= 2
        let file = printf("/tmp/.slime.mma.%c.m", 97 + g:slime_mma_paste_index)
        let g:slime_mma_paste_index = (g:slime_mma_paste_index + 1) % 26
        call writefile(split(a:text, "\n"), file, "b")
        return ["Get[\"" . file . "\"]\n"]
      else
        return [text . "\n"]
      endif
    endfunction

    function! _EscapeText_asir(text) abort
      let text = substitute(a:text, "\n*$", "", "")
      if count(text, "\n") >= 2
        let file = printf("/tmp/.slime.asir.%c.rr", 97 + g:slime_asir_paste_index)
        let g:slime_asir_paste_index = (g:slime_asir_paste_index + 1) % 26
        call writefile(add(split(a:text, "\n"), "end$"), file, "b")
        return ["load(\"" . file . "\");\n"]
      else
        return [text . "\n"]
      endif
    endfunction
  ]])
end

local function make_repl_name(command)
  local base = 'repl://' .. command:gsub('%s+', '_')
  local candidate = base
  local suffix = 2

  while vim.fn.bufexists(candidate) == 1 do
    candidate = ('%s#%d'):format(base, suffix)
    suffix = suffix + 1
  end

  return candidate
end

local function close_terminal_windows(terminal_buf)
  for _, win in ipairs(vim.fn.win_findbuf(terminal_buf)) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
end

local function set_slime_target(source_buf, terminal_buf)
  local ok, jobid = pcall(vim.api.nvim_get_option_value, 'channel', { buf = terminal_buf })
  if not ok or not jobid or jobid <= 0 then
    vim.notify('Could not detect terminal job id for vim-slime.', vim.log.levels.WARN)
    return
  end

  local ok_pid, pid = pcall(vim.fn.jobpid, jobid)
  vim.b[source_buf].slime_config = {
    jobid = jobid,
    pid = ok_pid and pid or '',
  }
  vim.b[source_buf].slime_target = 'neovim'
end

local function configure_repl_terminal_buffer(terminal_buf, command)
  vim.bo[terminal_buf].bufhidden = 'hide'
  vim.b[terminal_buf].is_user_repl = true

  local ok_name = pcall(vim.api.nvim_buf_set_name, terminal_buf, make_repl_name(command))
  if not ok_name then
    vim.notify('Could not rename REPL terminal buffer.', vim.log.levels.WARN)
  end

  vim.api.nvim_create_autocmd('BufEnter', {
    buffer = terminal_buf,
    callback = function()
      if vim.bo[terminal_buf].buftype == 'terminal' then
        vim.cmd('startinsert')
      end
    end,
  })

  vim.api.nvim_create_autocmd('TermClose', {
    buffer = terminal_buf,
    once = true,
    callback = function()
      vim.schedule(function()
        close_terminal_windows(terminal_buf)
      end)
    end,
  })
end

local function configure_repl_terminal_window(terminal_window)
  vim.wo[terminal_window].number = false
  vim.wo[terminal_window].relativenumber = false
  vim.wo[terminal_window].signcolumn = 'no'
  vim.wo[terminal_window].foldcolumn = '0'
  vim.wo[terminal_window].statuscolumn = ''
  vim.wo[terminal_window].cursorline = false
end

local function open_repl(layout, args)
  local argv = vim.deepcopy(args)
  local size

  if #argv > 0 and tonumber(argv[1]) then
    size = tonumber(table.remove(argv, 1))
  end

  local command = table.concat(argv, ' ')
  if command == '' then
    vim.notify('Usage: :ReplV [size] {command} or :ReplH [size] {command}', vim.log.levels.ERROR)
    return
  end

  local source_buf = vim.api.nvim_get_current_buf()

  if layout == 'vertical' then
    size = size or 120
    vim.cmd(('vertical botright %dsplit'):format(size))
  else
    size = size or 25
    vim.cmd(('botright %dsplit'):format(size))
  end

  vim.cmd('enew')
  local terminal_buf = vim.api.nvim_get_current_buf()
  vim.fn.termopen(command)

  local terminal_window = vim.api.nvim_get_current_win()
  configure_repl_terminal_buffer(terminal_buf, command)
  configure_repl_terminal_window(terminal_window)

  if layout == 'vertical' then
    vim.cmd(('vertical resize %d'):format(size))
    vim.wo.winfixwidth = true
  else
    vim.cmd(('resize %d'):format(size))
    vim.wo.winfixheight = true
  end

  set_slime_target(source_buf, terminal_buf)
  vim.cmd('wincmd p')
end

ensure_slime_defaults()
define_repl_escape_functions()

vim.api.nvim_create_user_command('Repl', function(command_opts)
  open_repl('vertical', command_opts.fargs)
end, { nargs = '+' })

vim.api.nvim_create_user_command('ReplV', function(command_opts)
  open_repl('vertical', command_opts.fargs)
end, { nargs = '+' })

vim.api.nvim_create_user_command('ReplH', function(command_opts)
  open_repl('horizontal', command_opts.fargs)
end, { nargs = '+' })

-- [[ Wolfram helpers ]]

vim.g.wolfram_definition_search_paths = vim.g.wolfram_definition_search_paths or { '~/.local/share/Wolfram/ApplicationData/Applications' }
vim.g.wolfram_definition_query_runtime_path = vim.g.wolfram_definition_query_runtime_path
if vim.g.wolfram_definition_query_runtime_path == nil then vim.g.wolfram_definition_query_runtime_path = 1 end
vim.g.wolfram_definition_path_exclude_patterns = vim.g.wolfram_definition_path_exclude_patterns
  or {
    '/Documentation/',
    '/SystemFiles/Data/',
    '/SystemFiles/Links/',
  }

local wolfram_runtime_paths_cache = nil
local wolfram_completion_symbols_cache = {}

local function wolfram_cache_dir()
  local cache_dir = vim.fs.joinpath(vim.fn.stdpath 'cache', 'wolfram')
  vim.fn.mkdir(cache_dir, 'p')
  return cache_dir
end

local function wolfram_runtime_paths_cache_file()
  return vim.fs.joinpath(wolfram_cache_dir(), 'runtime-paths.txt')
end

local function wolfram_symbols_cache_key(paths)
  local hash = 5381
  local joined = table.concat(paths, '\n')
  for i = 1, #joined do
    hash = (hash * 33 + joined:byte(i)) % 2147483647
  end
  return string.format('%08x', hash)
end

local function wolfram_symbols_cache_file(paths)
  return vim.fs.joinpath(wolfram_cache_dir(), 'symbols-' .. wolfram_symbols_cache_key(paths) .. '.txt')
end

local function wolfram_path_query_code()
  return table.concat({
    'userInit = FileNameJoin[{$UserBaseDirectory, "Kernel", "init.m"}]',
    'If[FileExistsQ[userInit], Get[userInit]]',
    'WriteString[$Output, "__WOLFRAM_PATH_BEGIN__\\n"]',
    'Scan[If[StringQ[#], WriteString[$Output, # <> "\\n"]] &, $Path]',
    'WriteString[$Output, "__WOLFRAM_PATH_END__\\n"]',
    'Exit[]',
  }, '; ')
end

local function wolfram_path_relevant(path)
  local expanded = vim.fn.fnamemodify(path, ':p')
  local home = vim.fn.fnamemodify(vim.env.HOME, ':p')

  if expanded == home then return false end

  for _, pattern in ipairs(vim.g.wolfram_definition_path_exclude_patterns or {}) do
    if expanded:find(pattern) then return false end
  end

  return true
end

local function wolfram_path_rank(path)
  local expanded = vim.fn.fnamemodify(path, ':p')
  local home = vim.env.HOME
  local prefixes = {
    { 10, vim.fn.fnamemodify(home .. '/dev/', ':p') },
    { 10, vim.fn.fnamemodify(home .. '/soft/', ':p') },
    { 20, vim.fn.fnamemodify(home .. '/.Wolfram/Applications/', ':p') },
    { 20, vim.fn.fnamemodify(home .. '/.local/share/Wolfram/ApplicationData/Applications/', ':p') },
    { 30, vim.fn.fnamemodify(home .. '/.Wolfram/Autoload/', ':p') },
    { 40, vim.fn.fnamemodify(home .. '/.Wolfram/Kernel/', ':p') },
  }

  for _, item in ipairs(prefixes) do
    if expanded:sub(1, #item[2]) == item[2] then return item[1] end
  end
  if expanded:find '/AddOns/%f[^/](Applications|Packages|Autoload|ExtraPackages)/' then return 50 end
  if expanded:find '/SystemFiles/%f[^/](Kernel/Packages|Autoload)/' then return 60 end
  return 90
end

local function curate_wolfram_runtime_paths(paths)
  local curated = {}
  local seen = {}

  for _, path in ipairs(paths) do
    local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
    if vim.fn.isdirectory(expanded) == 1 and wolfram_path_relevant(expanded) and not seen[expanded] then
      seen[expanded] = true
      table.insert(curated, expanded)
    end
  end

  table.sort(curated, function(left, right)
    local left_rank = wolfram_path_rank(left)
    local right_rank = wolfram_path_rank(right)
    if left_rank == right_rank then return left < right end
    return left_rank < right_rank
  end)

  return curated
end

local function wolfram_kernel_command(run_expr)
  local candidates = {
    { 'WolframKernel', '-noprompt', '-nopaclet', '-nostartuppaclets', '-noicon', '-run', run_expr },
    { 'wolfram', '-noprompt', '-nopaclet', '-nostartuppaclets', '-noicon', '-run', run_expr },
    { 'wolframscript', '-code', run_expr },
    { 'math', '-noprompt', '-run', run_expr },
  }

  for _, cmd in ipairs(candidates) do
    if vim.fn.executable(cmd[1]) == 1 then return cmd end
  end

  return nil
end

local function wolfram_runtime_paths()
  if wolfram_runtime_paths_cache then return vim.deepcopy(wolfram_runtime_paths_cache) end

  local cache_file = wolfram_runtime_paths_cache_file()
  if vim.fn.filereadable(cache_file) == 1 then
    local paths = curate_wolfram_runtime_paths(vim.fn.readfile(cache_file))
    vim.fn.writefile(paths, cache_file)
    wolfram_runtime_paths_cache = paths
    return vim.deepcopy(paths)
  end

  if tonumber(vim.g.wolfram_definition_query_runtime_path or 0) == 0 then return {} end

  local cmd = wolfram_kernel_command(wolfram_path_query_code())
  if not cmd then
    wolfram_runtime_paths_cache = {}
    return {}
  end

  local output = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    wolfram_runtime_paths_cache = {}
    return {}
  end

  local start_idx = vim.fn.index(output, '__WOLFRAM_PATH_BEGIN__')
  local end_idx = vim.fn.index(output, '__WOLFRAM_PATH_END__')
  local raw_paths = {}
  if start_idx >= 0 and end_idx > start_idx then raw_paths = vim.list_slice(output, start_idx + 2, end_idx) end

  local paths = curate_wolfram_runtime_paths(raw_paths)
  vim.fn.writefile(paths, cache_file)
  wolfram_runtime_paths_cache = paths
  return vim.deepcopy(paths)
end

local function wolfram_search_paths(bufnr)
  local paths = {}
  local seen = {}
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local root = vim.fs.root(bufnr, { '.git' })

  local function add_path(path)
    if not path or path == '' then return end
    local expanded = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
    if vim.fn.isdirectory(expanded) == 1 and not seen[expanded] then
      seen[expanded] = true
      table.insert(paths, expanded)
    end
  end

  add_path(root or (filename ~= '' and vim.fs.dirname(filename) or nil))

  for _, path in ipairs(wolfram_runtime_paths()) do
    add_path(path)
  end
  for _, path in ipairs(vim.g.wolfram_definition_search_paths or {}) do
    add_path(path)
  end

  return paths
end

local function wolfram_extract_definition_symbol(line)
  return line:match '^%s*([A-Za-z$`][A-Za-z0-9$`]*)'
end

local function wolfram_add_completion_symbol(symbols, symbol)
  if not symbol or symbol == '' then return end
  symbols[symbol] = true

  local tail = symbol:match '.*`(.*)$'
  if tail and tail ~= '' then symbols[tail] = true end
end

local function wolfram_build_completion_symbols(paths)
  if #paths == 0 or vim.fn.executable 'rg' ~= 1 then return {} end

  local cmd = {
    'rg',
    '--no-filename',
    '--no-heading',
    '--color=never',
    '--glob',
    '*.m',
    '--glob',
    '*.wl',
    '^\\s*[A-Za-z$`][A-Za-z0-9$`]*(\\s*::usage\\s*=|\\s*\\[.*\\]\\s*(:=|=)|\\s*(:=|=))',
  }
  vim.list_extend(cmd, paths)

  local lines = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then return {} end

  local symbols = {}
  for _, line in ipairs(lines) do
    wolfram_add_completion_symbol(symbols, wolfram_extract_definition_symbol(line))
  end

  return vim.fn.sort(vim.tbl_keys(symbols))
end

local function wolfram_completion_symbols(bufnr)
  local paths = wolfram_search_paths(bufnr)
  local cache_key = wolfram_symbols_cache_key(paths)
  local cache_file = wolfram_symbols_cache_file(paths)

  if wolfram_completion_symbols_cache[cache_key] then return vim.deepcopy(wolfram_completion_symbols_cache[cache_key]) end

  if vim.fn.filereadable(cache_file) == 1 then
    local symbols = vim.fn.readfile(cache_file)
    wolfram_completion_symbols_cache[cache_key] = symbols
    return vim.deepcopy(symbols)
  end

  local symbols = wolfram_build_completion_symbols(paths)
  if #symbols > 0 then vim.fn.writefile(symbols, cache_file) end
  wolfram_completion_symbols_cache[cache_key] = symbols
  return vim.deepcopy(symbols)
end

local function wolfram_clear_completion_symbols()
  wolfram_completion_symbols_cache = {}
  local cache_dir = wolfram_cache_dir()
  for _, cache_file in ipairs(vim.fn.glob(cache_dir .. '/symbols-*.txt', false, true)) do
    vim.fn.delete(cache_file)
  end
end

local function wolfram_refresh_paths()
  wolfram_runtime_paths_cache = nil
  local cache_file = wolfram_runtime_paths_cache_file()
  if vim.fn.filereadable(cache_file) == 1 then vim.fn.delete(cache_file) end
  wolfram_clear_completion_symbols()

  local paths = wolfram_runtime_paths()
  vim.notify(('Refreshed Wolfram $Path cache (%d entries) and cleared symbol cache'):format(#paths), vim.log.levels.INFO)
end

local function wolfram_refresh_symbols()
  wolfram_clear_completion_symbols()
  local symbols = wolfram_completion_symbols(vim.api.nvim_get_current_buf())
  vim.notify(('Refreshed Wolfram symbol cache (%d entries)'):format(#symbols), vim.log.levels.INFO)
end

local function wolfram_goto_definition()
  if vim.fn.executable 'rg' ~= 1 then
    vim.notify('ripgrep is required for WolframGotoDefinition.', vim.log.levels.ERROR)
    return
  end

  local symbol = vim.fn.expand '<cword>'
  if symbol == '' then
    vim.notify('No Wolfram symbol under cursor.', vim.log.levels.ERROR)
    return
  end

  local paths = wolfram_search_paths(vim.api.nvim_get_current_buf())
  if #paths == 0 then
    vim.notify('No Wolfram definition search paths are configured.', vim.log.levels.ERROR)
    return
  end

  local pattern = '^\\s*'
    .. vim.fn.escape(symbol, [[\.^$~[]*+?()|{}]])
    .. '(\\s*::usage\\s*=|\\s*\\[.*\\]\\s*(:=|=)|\\s*(:=|=))'
  local cmd = {
    'rg',
    '--column',
    '--line-number',
    '--no-heading',
    '--smart-case',
    '--color=never',
    '--glob',
    '*.m',
    '--glob',
    '*.wl',
    pattern,
  }
  vim.list_extend(cmd, paths)

  local matches = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 or vim.tbl_isempty(matches) then
    vim.notify('No Wolfram definition found for ' .. symbol, vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, 'r', {
    title = 'Wolfram definitions for ' .. symbol,
    lines = matches,
    efm = '%f:%l:%c:%m',
  })

  if #matches == 1 then
    vim.cmd.cfirst()
  else
    vim.cmd.copen()
  end
end

vim.api.nvim_create_user_command('WolframGotoDefinition', wolfram_goto_definition, {})
vim.api.nvim_create_user_command('WolframRefreshPaths', wolfram_refresh_paths, {})
vim.api.nvim_create_user_command('WolframRefreshSymbols', wolfram_refresh_symbols, {})

-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then error('Error cloning lazy.nvim:\n' .. out) end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added via a link or github org/name. To run setup automatically, use `opts = {}`
  { 'NMAC427/guess-indent.nvim', opts = {} },

  {
    'jpalardy/vim-slime',
    lazy = false,
    init = ensure_slime_defaults,
    config = function()
      vim.keymap.set('n', '<F1>', '<Plug>SlimeParagraphSend', {
        remap = true,
        silent = true,
        desc = 'Send paragraph to REPL',
      })
      vim.keymap.set('x', '<F1>', '<Plug>SlimeRegionSend', {
        remap = true,
        silent = true,
        desc = 'Send selection to REPL',
      })
    end,
  },

  -- Alternatively, use `config = function() ... end` for full control over the configuration.
  -- If you prefer to call `setup` explicitly, use:
  --    {
  --        'lewis6991/gitsigns.nvim',
  --        config = function()
  --            require('gitsigns').setup({
  --                -- Your gitsigns configuration here
  --            })
  --        end,
  --    }
  --
  -- Here is a more advanced example where we pass configuration
  -- options to `gitsigns.nvim`.
  --
  -- See `:help gitsigns` to understand what the configuration keys do
  { -- Adds git related signs to the gutter, as well as utilities for managing changes
    'lewis6991/gitsigns.nvim',
    ---@module 'gitsigns'
    ---@type Gitsigns.Config
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      signs = {
        add = { text = '+' }, ---@diagnostic disable-line: missing-fields
        change = { text = '~' }, ---@diagnostic disable-line: missing-fields
        delete = { text = '_' }, ---@diagnostic disable-line: missing-fields
        topdelete = { text = '^' }, ---@diagnostic disable-line: missing-fields
        changedelete = { text = '~' }, ---@diagnostic disable-line: missing-fields
      },
    },
  },

  {
    'tpope/vim-fugitive',
  },

  -- NOTE: Plugins can also be configured to run Lua code when they are loaded.
  --
  -- This is often very useful to both group configuration, as well as handle
  -- lazy loading plugins that don't need to be loaded immediately at startup.
  --
  -- For example, in the following configuration, we use:
  --  event = 'VimEnter'
  --
  -- which loads which-key before all the UI elements are loaded. Events can be
  -- normal autocommands events (`:help autocmd-events`).
  --
  -- Then, because we use the `opts` key (recommended), the configuration runs
  -- after the plugin has been loaded as `require(MODULE).setup(opts)`.

  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter',
    ---@module 'which-key'
    ---@type wk.Opts
    ---@diagnostic disable-next-line: missing-fields
    opts = {
      -- delay between pressing a key and opening which-key (milliseconds)
      delay = 0,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = {
          Up = 'Up ',
          Down = 'Down ',
          Left = 'Left ',
          Right = 'Right ',
          C = 'Ctrl+',
          M = 'Alt+',
          D = 'Super+',
          S = 'Shift+',
          CR = 'Enter',
          Esc = 'Esc',
          ScrollWheelDown = 'WheelDown',
          ScrollWheelUp = 'WheelUp',
          NL = 'Enter',
          BS = 'Backspace',
          Space = 'Space',
          Tab = 'Tab',
          F1 = 'F1',
          F2 = 'F2',
          F3 = 'F3',
          F4 = 'F4',
          F5 = 'F5',
          F6 = 'F6',
          F7 = 'F7',
          F8 = 'F8',
          F9 = 'F9',
          F10 = 'F10',
          F11 = 'F11',
          F12 = 'F12',
        },
      },

      -- Document existing key chains
      spec = {
        { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } }, -- Enable gitsigns recommended keymaps first
        { 'gr', group = 'LSP Actions', mode = { 'n' } },
      },
    },
  },

  -- NOTE: Plugins can specify dependencies.
  --
  -- The dependencies are proper plugin specifications as well - anything
  -- you do for a plugin at the top level, you can do for a dependency.
  --
  -- Use the `dependencies` key to specify the dependencies of a particular plugin

  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    -- By default, Telescope is included and acts as your picker for everything.

    -- If you would like to switch to a different picker (like snacks, or fzf-lua)
    -- you can disable the Telescope plugin by setting enabled to false and enable
    -- your replacement picker by requiring it explicitly (e.g. 'custom.plugins.snacks')

    -- Note: If you customize your config for yourself,
    -- it’s best to remove the Telescope plugin config entirely
    -- instead of just disabling it here, to keep your config clean.
    enabled = true,
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function() return vim.fn.executable 'make' == 1 end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      local actions = require 'telescope.actions'

      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        defaults = {
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
            },
            n = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
            },
          },
        },
        extensions = {
          ['ui-select'] = { require('telescope.themes').get_dropdown() },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set({ 'n', 'v' }, '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

      -- This runs on LSP attach per buffer (see main LSP attach function in 'neovim/nvim-lspconfig' config for more info,
      -- it is better explained there). This allows easily switching between pickers if you prefer using something else!
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('telescope-lsp-attach', { clear = true }),
        callback = function(event)
          local buf = event.buf

          -- Find references for the word under your cursor.
          vim.keymap.set('n', 'grr', builtin.lsp_references, { buffer = buf, desc = '[G]oto [R]eferences' })

          -- Jump to the implementation of the word under your cursor.
          -- Useful when your language has ways of declaring types without an actual implementation.
          vim.keymap.set('n', 'gri', builtin.lsp_implementations, { buffer = buf, desc = '[G]oto [I]mplementation' })

          -- Jump to the definition of the word under your cursor.
          -- This is where a variable was first declared, or where a function is defined, etc.
          -- To jump back, press <C-t>.
          vim.keymap.set('n', 'grd', builtin.lsp_definitions, { buffer = buf, desc = '[G]oto [D]efinition' })

          -- Fuzzy find all the symbols in your current document.
          -- Symbols are things like variables, functions, types, etc.
          vim.keymap.set('n', 'gO', builtin.lsp_document_symbols, { buffer = buf, desc = 'Open Document Symbols' })

          -- Fuzzy find all the symbols in your current workspace.
          -- Similar to document symbols, except searches over your entire project.
          vim.keymap.set('n', 'gW', builtin.lsp_dynamic_workspace_symbols, { buffer = buf, desc = 'Open Workspace Symbols' })

          -- Jump to the type of the word under your cursor.
          -- Useful when you're not sure what type a variable is and you want to see
          -- the definition of its *type*, not where it was *defined*.
          vim.keymap.set('n', 'grt', builtin.lsp_type_definitions, { buffer = buf, desc = '[G]oto [T]ype Definition' })
        end,
      })

      -- Override default behavior and theme when searching
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          winblend = 10,
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set(
        'n',
        '<leader>s/',
        function()
          builtin.live_grep {
            grep_open_files = true,
            prompt_title = 'Live Grep in Open Files',
          }
        end,
        { desc = '[S]earch [/] in Open Files' }
      )

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function() builtin.find_files { cwd = vim.fn.stdpath 'config' } end, { desc = '[S]earch [N]eovim files' })
    end,
  },

  -- LSP Plugins
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      -- Automatically install LSPs and related tools to stdpath for Neovim
      -- Mason must be loaded before its dependents so we need to set it up here.
      -- NOTE: `opts = {}` is the same as calling `require('mason').setup({})`
      {
        'mason-org/mason.nvim',
        ---@module 'mason.settings'
        ---@type MasonSettings
        ---@diagnostic disable-next-line: missing-fields
        opts = {},
      },
      -- Maps LSP server names between nvim-lspconfig and Mason package names.
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',

      -- Useful status updates for LSP.
      { 'j-hui/fidget.nvim', opts = {} },
    },
    config = function()
      -- Brief aside: **What is LSP?**
      --
      -- LSP is an initialism you've probably heard, but might not understand what it is.
      --
      -- LSP stands for Language Server Protocol. It's a protocol that helps editors
      -- and language tooling communicate in a standardized fashion.
      --
      -- In general, you have a "server" which is some tool built to understand a particular
      -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
      -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
      -- processes that communicate with some "client" - in this case, Neovim!
      --
      -- LSP provides Neovim with features like:
      --  - Go to definition
      --  - Find references
      --  - Autocompletion
      --  - Symbol Search
      --  - and more!
      --
      -- Thus, Language Servers are external tools that must be installed separately from
      -- Neovim. This is where `mason` and related plugins come into play.
      --
      -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
      -- and elegantly composed help section, `:help lsp-vs-treesitter`

      --  This function gets run when an LSP attaches to a particular buffer.
      --    That is to say, every time a new file is opened that is associated with
      --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
      --    function will be executed to configure the current buffer
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          -- NOTE: Remember that Lua is a real programming language, and as such it is possible
          -- to define small helper and utility functions so you don't have to repeat yourself.
          --
          -- In this case, we create a function that lets us more easily define mappings specific
          -- for LSP related items. It sets the mode, buffer and description for us each time.
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          -- Rename the variable under your cursor.
          --  Most Language Servers support renaming across files, etc.
          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

          -- Execute a code action, usually your cursor needs to be on top of an error
          -- or a suggestion from your LSP for this to activate.
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

          -- WARN: This is not Goto Definition, this is Goto Declaration.
          --  For example, in C this would take you to the header.
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          -- The following two autocommands are used to highlight references of the
          -- word under your cursor when your cursor rests there for a little while.
          --    See `:help CursorHold` for information about when this is executed
          --
          -- When you move your cursor, the highlights will be cleared (the second autocommand).
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          -- The following code creates a keymap to toggle inlay hints in your
          -- code, if the language server you are using supports them
          --
          -- This may be unwanted, since they displace some of your code
          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Enable the following language servers
      --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
      --  See `:help lsp-config` for information about keys and how to configure
      ---@type table<string, vim.lsp.Config>
      local servers = {
        clangd = {
          cmd = {
            'clangd',
            '--background-index',
            '--clang-tidy',
            '--query-driver=/usr/bin/c++,/usr/bin/g++',
          },
        },
        -- gopls = {},
        pylsp = {},
        -- rust_analyzer = {},
        --
        -- Some languages (like typescript) have entire language plugins that can be useful:
        --    https://github.com/pmizio/typescript-tools.nvim
        --
        -- But for many setups, the LSP (`ts_ls`) will work just fine
        -- ts_ls = {},
        julials = {
          cmd = function(dispatchers, config)
            local julia_lsp = vim.fn.expand '~/.local/bin/julia-lsp'

            if vim.fn.executable(julia_lsp) ~= 1 then julia_lsp = vim.fn.exepath 'julia-lsp' end

            if julia_lsp == '' then
              local mason_julia_lsp = vim.fs.joinpath(vim.fn.stdpath 'data', 'mason', 'bin', 'julia-lsp')
              if vim.fn.executable(mason_julia_lsp) == 1 then julia_lsp = mason_julia_lsp end
            end

            local root = (config or {}).root_dir or vim.fn.getcwd()
            return vim.lsp.rpc.start({ julia_lsp, root }, dispatchers)
          end,
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, { { 'Project.toml', 'JuliaProject.toml' }, { '.git' } })
            local filename = vim.api.nvim_buf_get_name(bufnr)

            if not root and filename ~= '' then root = vim.fs.dirname(filename) end
            if not root or root == '' then root = vim.fn.getcwd() end

            on_dir(root)
          end,
          single_file_support = true,
        },
        wolfram_lsp = {
          cmd = function(dispatchers, config)
            local wolfram_lsp = vim.fn.expand '~/.local/bin/wolfram-lsp'

            if vim.fn.executable(wolfram_lsp) ~= 1 then wolfram_lsp = vim.fn.exepath 'wolfram-lsp' end
            if wolfram_lsp == '' then return nil end

            return vim.lsp.rpc.start({ wolfram_lsp }, dispatchers, { cwd = (config or {}).root_dir or vim.fn.getcwd() })
          end,
          filetypes = { 'mma' },
          root_dir = function(bufnr, on_dir)
            local root = vim.fs.root(bufnr, { 'PacletInfo.wl', '.git' })
            local filename = vim.api.nvim_buf_get_name(bufnr)

            if not root and filename ~= '' then root = vim.fs.dirname(filename) end
            if not root or root == '' then root = vim.fn.getcwd() end

            on_dir(root)
          end,
          single_file_support = true,
        },

        stylua = {}, -- Used to format Lua code

        -- Special Lua Config, as recommended by neovim help docs
        lua_ls = {
          on_init = function(client)
            client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

            if client.workspace_folders then
              local path = client.workspace_folders[1].name
              if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
              runtime = {
                version = 'LuaJIT',
                path = { 'lua/?.lua', 'lua/?/init.lua' },
              },
              workspace = {
                checkThirdParty = false,
                -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
                --  See https://github.com/neovim/nvim-lspconfig/issues/3189
                library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                  '${3rd}/luv/library',
                  '${3rd}/busted/library',
                }),
              },
            })
          end,
          ---@type lspconfig.settings.lua_ls
          settings = {
            Lua = {
              format = { enable = false }, -- Disable formatting (formatting is done by stylua)
            },
          },
        },
      }

      -- Ensure the servers and tools above are installed
      --
      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --    :Mason
      --
      -- You can press `g?` for help in this menu.
      local manual_servers = {
        wolfram_lsp = true,
      }
      local ensure_installed = {}
      for name, _ in pairs(servers or {}) do
        if not manual_servers[name] then table.insert(ensure_installed, name) end
      end
      vim.list_extend(ensure_installed, {
        -- You can add other tools here that you want Mason to install
      })

      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end
    end,
  },

  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function() require('conform').format { async = true } end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        -- You can specify filetypes to autoformat on save here:
        local enabled_filetypes = {
          -- lua = true,
          -- python = true,
        }
        if enabled_filetypes[vim.bo[bufnr].filetype] then
          return { timeout_ms = 500 }
        else
          return nil
        end
      end,
      default_format_opts = {
        lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting. Set to `false` to disable LSP formatting entirely.
      },
      -- You can also specify external formatters in here.
      formatters_by_ft = {
        -- rust = { 'rustfmt' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },

  { -- Autocompletion
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '1.*',
    dependencies = {
      -- Snippet Engine
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          -- Build Step is needed for regex support in snippets.
          -- This step is not supported in many windows environments.
          -- Remove the below condition to re-enable on windows.
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then return end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          -- `friendly-snippets` contains a variety of premade snippets.
          --    See the README about individual language/framework/plugin snippets:
          --    https://github.com/rafamadriz/friendly-snippets
          -- {
          --   'rafamadriz/friendly-snippets',
          --   config = function()
          --     require('luasnip.loaders.from_vscode').lazy_load()
          --   end,
          -- },
        },
        config = function()
          local ls = require 'luasnip'
          local s = ls.snippet
          local i = ls.insert_node
          local t = ls.text_node
          local fmt = require('luasnip.extras.fmt').fmt
          local rep = require('luasnip.extras').rep

          ls.setup {}

          ls.add_snippets('mma', {
            s(
              'mod',
              fmt(
                [[
                  Module[{{{}}}, 
                    {}
                  ]
                ]],
                { i(1), i(0) }
              )
            ),
            s(
              'blk',
              fmt(
                [[
                  Block[{{{}}}, 
                    {}
                  ]
                ]],
                { i(1), i(0) }
              )
            ),
            s(
              'wh',
              fmt(
                [[
                  Which[
                    {}, {},
                    True, {}
                  ]
                ]],
                { i(1, 'condition'), i(2, 'value'), i(0) }
              )
            ),
            s('usage', fmt([[{}::usage = "{}";]], { i(1, 'symbol'), i(0, 'description') })),
            s(
              'rcomp',
              fmt(
                [[
                  RightComposition[
                    {},
                    Identity
                  ]
                ]],
                { i(0) }
              )
            ),
          })

          local tex_snippets = {
            s(
              'beg',
              fmt(
                [[
                  \begin{{{}}}
                    {}
                  \end{{{}}}
                ]],
                { i(1, 'env'), i(0), rep(1) }
              )
            ),
            s(
              'ali',
              fmt(
                [[
                  \begin{{align}}
                    {}
                  \end{{align}}
                ]],
                { i(0) }
              )
            ),
            s(
              'fig',
              fmt(
                [[
                  \begin{{figure}}[{}]
                    \centering
                    \includegraphics[width={}\textwidth]{{{}}}
                    \caption{{{}}}
                    \label{{fig:{}}}
                  \end{{figure}}
                ]],
                { i(1, 'tbp'), i(2, '0.8'), i(3, 'file'), i(4, 'caption'), i(5, 'label') }
              )
            ),
            s(
              'thm',
              fmt(
                [[
                  \begin{{theorem}}[{}]
                    {}
                  \end{{theorem}}
                ]],
                { i(1, 'name'), i(0) }
              )
            ),
          }

          ls.add_snippets('tex', tex_snippets)
          ls.add_snippets('plaintex', tex_snippets)
        end,
      },
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      keymap = {
        -- 'default' (recommended) for mappings similar to built-in completions
        --   <c-y> to accept ([y]es) the completion.
        --    This will auto-import if your LSP supports it.
        --    This will expand snippets if the LSP sent a snippet.
        -- 'super-tab' for tab to accept
        -- 'enter' for enter to accept
        -- 'none' for no mappings
        --
        -- For an understanding of why the 'default' preset is recommended,
        -- you will need to read `:help ins-completion`
        --
        -- No, but seriously. Please read `:help ins-completion`, it is really good!
        --
        -- All presets have the following mappings:
        -- <tab>/<s-tab>: move to right/left of your snippet expansion
        -- <c-space>: Open menu or open docs if already open
        -- <c-n>/<c-p> or <up>/<down>: Select next/previous item
        -- <c-e>: Hide menu
        -- <c-k>: Toggle signature help
        --
        -- See :h blink-cmp-config-keymap for defining your own keymap
        preset = 'default',
        ['<Tab>'] = {
          function(cmp) return cmp.select_and_accept() end,
          'snippet_forward',
          'fallback',
        },

        -- For more advanced Luasnip keymaps (e.g. selecting choice nodes, expansion) see:
        --    https://github.com/L3MON4D3/LuaSnip?tab=readme-ov-file#keymaps
      },

      appearance = {
        -- 'mono' (default) for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
        -- Adjusts spacing to ensure icons are aligned
        nerd_font_variant = 'mono',
      },

      completion = {
        -- By default, you may press `<c-space>` to show the documentation.
        -- Optionally, set `auto_show = true` to show the documentation after a delay.
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets' },
      },

      snippets = { preset = 'luasnip' },

      -- Blink.cmp includes an optional, recommended rust fuzzy matcher,
      -- which automatically downloads a prebuilt binary when enabled.
      --
      -- By default, we use the Lua implementation instead, but you may enable
      -- the rust implementation via `'prefer_rust_with_warning'`
      --
      -- See :h blink-cmp-config-fuzzy for more information
      fuzzy = { implementation = 'lua' },

      -- Shows a signature help window while you type arguments for a function
      signature = { enabled = true },
    },
  },

  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        styles = {
          comments = { italic = false }, -- Disable italics in comments
        },
      }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },

  { -- Collection of various small independent plugins/modules
    'nvim-mini/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yiiq - [Y]ank [I]nside [I]+1 [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup {
        -- NOTE: Avoid conflicts with the built-in incremental selection mappings on Neovim>=0.12 (see `:help treesitter-incremental-selection`)
        mappings = {
          around_next = 'aa',
          inside_next = 'ii',
        },
        n_lines = 500,
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Simple and easy statusline.
      --  You could remove this setup call if you don't like it,
      --  and try some other statusline plugin
      local statusline = require 'mini.statusline'
      -- set use_icons to true if you have a Nerd Font
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- You can configure sections in the statusline by overriding their
      -- default behavior. For example, here we set the section for
      -- cursor location to LINE:COLUMN
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function() return '%2l:%-2v' end

      -- ... and there is more!
      --  Check out: https://github.com/nvim-mini/mini.nvim
    end,
  },

  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'master',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter-intro`
    config = function()
      local nvim_treesitter = require 'nvim-treesitter'
      local ts_install = require 'nvim-treesitter.install'
      local ts_info = require 'nvim-treesitter.info'
      local ts_parsers = require 'nvim-treesitter.parsers'
      local ts_site_dir = vim.fn.stdpath 'data' .. '/site'

      nvim_treesitter.setup()
      ts_install.ts_generate_args = { 'generate', '--abi', tostring(vim.treesitter.language_version) }
      require('nvim-treesitter.configs').setup {
        parser_install_dir = ts_site_dir,
      }
      vim.opt.runtimepath:prepend(ts_site_dir)

      local function register_wolfram_parser()
        ts_parsers.get_parser_configs().wolfram = {
          install_info = {
            url = 'https://github.com/LumaKernel/tree-sitter-wolfram',
            branch = 'main',
            files = { 'src/parser.c', 'src/scanner.c' },
            queries = 'queries',
            generate = true,
            generate_from_json = false,
          },
          filetype = 'mma',
          tier = 2,
        }
        vim.treesitter.language.register('wolfram', 'mma')
      end

      register_wolfram_parser()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'TSUpdate',
        group = vim.api.nvim_create_augroup('dotfiles-wolfram-treesitter', { clear = true }),
        callback = register_wolfram_parser,
      })

      -- ensure basic parser are installed
      local parsers = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc', 'wolfram' }
      ts_install.ensure_installed(parsers)

      ---@param buf integer
      ---@param language string
      local function treesitter_try_attach(buf, language)
        -- check if parser exists and load it
        if not vim.treesitter.language.add(language) then return end
        -- enables syntax highlighting and other treesitter features
        vim.treesitter.start(buf, language)

        -- enables treesitter based folds
        -- for more info on folds see `:help folds`
        vim.wo[0].foldexpr = 'v:lua.vim.treesitter.foldexpr()'
        vim.wo[0].foldmethod = 'expr'

        -- check if treesitter indentation is available for this language, and if so enable it
        -- in case there is no indent query, the indentexpr will fallback to the vim's built in one
        local has_indent_query = vim.treesitter.query.get(language, 'indents') ~= nil

        -- enables treesitter based indentation
        if has_indent_query then vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()" end
      end

      local available_parsers = ts_parsers.available_parsers()
      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match

          local language = vim.treesitter.language.get_lang(filetype)
          if not language then return end

          local installed_parsers = ts_info.installed_parsers()

          if vim.tbl_contains(installed_parsers, language) then
            -- enable the parser if it is installed
            treesitter_try_attach(buf, language)
          elseif vim.tbl_contains(available_parsers, language) then
            -- Trigger installation in the background; attach on the next FileType/BufRead after install.
            ts_install.ensure_installed { language }
          else
            -- try to enable treesitter features in case the parser exists but is not available from `nvim-treesitter`
            treesitter_try_attach(buf, language)
          end
        end,
      })
    end,
  },

  -- The following comments only work if you have downloaded the kickstart repo, not just copy pasted the
  -- init.lua. If you want these files, they are in the repository, so you can just download them and
  -- place them in the correct locations.

  -- NOTE: Next step on your Neovim journey: Add/Configure additional plugins for Kickstart
  --
  --  Here are some example plugins that I've included in the Kickstart repository.
  --  Uncomment any of the lines below to enable them (you will need to restart nvim).
  --
  -- require 'kickstart.plugins.debug',
  -- require 'kickstart.plugins.indent_line',
  -- require 'kickstart.plugins.lint',
  -- require 'kickstart.plugins.autopairs',
  -- require 'kickstart.plugins.neo-tree',
  -- require 'kickstart.plugins.gitsigns', -- adds gitsigns recommended keymaps

  -- NOTE: The import below can automatically add your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
  --    This is the easiest way to modularize your config.
  --
  --  Uncomment the following line and add your plugins to `lua/custom/plugins/*.lua` to get going.
  -- { import = 'custom.plugins' },
  --
  -- For additional information with loading, sourcing and examples see `:help lazy.nvim-🔌-plugin-spec`
  -- Or use telescope!
  -- In normal mode type `<space>sh` then write `lazy.nvim-plugin`
  -- you can continue same window with `<space>sr` which resumes last telescope search
}, { ---@diagnostic disable-line: missing-fields
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define an ASCII table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '[cmd]',
      config = '[cfg]',
      event = '[evt]',
      ft = '[ft]',
      init = '[init]',
      keys = '[keys]',
      plugin = '[plug]',
      runtime = '[rt]',
      require = '[req]',
      source = '[src]',
      start = '[run]',
      task = '[todo]',
      lazy = '[lazy]',
    },
  },
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
