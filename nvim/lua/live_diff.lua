local M = {}

local namespace = vim.api.nvim_create_namespace("live_diff")
local state = {}
local global_enabled = false

local defaults = {
	auto_enable = false,
	debounce_ms = 120,
	base_ref = "HEAD",
	but_diff_cmd = "/Users/davidpdrsn/code/gitbutler/gitbutler-git/target/release/but",
	but_diff_cache_ms = 1000,
}

local config = vim.deepcopy(defaults)
local but_diff_cache = {}
local saved_guicursor
local saved_cursorline
local hidden_cursor_winid
local cursor_hidden = false

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "live_diff" })
end

local function system(cmd, opts)
	local result = vim.system(cmd, opts):wait()
	if result.code ~= 0 then
		return nil, vim.trim(result.stderr or result.stdout or "")
	end

	return result.stdout or ""
end

local function bufname(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return nil
	end

	return name
end

local function repo_root_for_buffer(bufnr)
	local name = bufname(bufnr)
	local cwd = name and vim.fs.dirname(name) or vim.fn.getcwd()
	local stdout, err = system({ "git", "rev-parse", "--show-toplevel" }, { cwd = cwd, text = true })
	if not stdout then
		return nil, err
	end

	return vim.trim(stdout)
end

local function relative_path(root, path)
	if vim.fs and vim.fs.relpath then
		return vim.fs.relpath(root, path)
	end

	if path:sub(1, #root + 1) == root .. "/" then
		return path:sub(#root + 2)
	end

	return nil
end

local function base_lines(root, pathspec)
	local stdout = system({ "git", "show", config.base_ref .. ":" .. pathspec }, { cwd = root, text = true })
	if not stdout then
		return {}
	end

	if stdout:sub(-1) == "\n" then
		stdout = stdout:sub(1, -2)
	end

	if stdout == "" then
		return {}
	end

	return vim.split(stdout, "\n", { plain = true })
end

local function current_lines(bufnr)
	return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function normalize_diff_hunk(hunk)
	if hunk.start_a then
		return hunk.start_a, hunk.count_a, hunk.start_b, hunk.count_b
	end

	return hunk[1], hunk[2], hunk[3], hunk[4]
end

local function ranges_overlap(start_a, count_a, start_b, count_b)
	local end_a = start_a + math.max(count_a, 1) - 1
	local end_b = start_b + math.max(count_b, 1) - 1
	return start_a <= end_b and start_b <= end_a
end

local function but_diff_changes(root)
	local now = vim.uv.now()
	local cached = but_diff_cache[root]
	if cached and now - cached.time < config.but_diff_cache_ms then
		return cached.changes
	end

	local stdout = system({ config.but_diff_cmd, "diff", "--json" }, { cwd = root, text = true })
	if not stdout then
		but_diff_cache[root] = { time = now, changes = {} }
		return {}
	end

	local ok, decoded = pcall(vim.json.decode, stdout)
	local changes = ok and decoded and decoded.changes or {}
	but_diff_cache[root] = { time = now, changes = changes }
	return changes
end

local function but_hunk_id(root, pathspec, hunk)
	for _, change in ipairs(but_diff_changes(root)) do
		if change.path == pathspec and change.diff and change.diff.type == "patch" then
			for _, but_hunk in ipairs(change.diff.hunks or {}) do
				local old_start = but_hunk.oldStart or but_hunk.old_start
				local old_lines = but_hunk.oldLines or but_hunk.old_lines or 0
				local new_start = but_hunk.newStart or but_hunk.new_start
				local new_lines = but_hunk.newLines or but_hunk.new_lines or 0
				if old_start and new_start then
					local old_matches = (hunk.old_count == 0 and old_lines == 0)
						or ranges_overlap(hunk.old_start, hunk.old_count, old_start, old_lines)
					local new_matches = (hunk.new_count == 0 and new_lines == 0)
						or ranges_overlap(hunk.new_start, hunk.new_count, new_start, new_lines)
					if old_matches and new_matches then
						return change.id
					end
				end
			end
		end
	end

	return nil
end

local function compute_hunks(old_lines, new_lines)
	local old_text = table.concat(old_lines, "\n")
	local new_text = table.concat(new_lines, "\n")
	local ok, diff = pcall(vim.diff, old_text, new_text, {
		result_type = "indices",
		algorithm = "histogram",
	})
	if not ok or not diff then
		return {}
	end

	local hunks = {}
	for _, raw_hunk in ipairs(diff) do
		local old_start, old_count, new_start, new_count = normalize_diff_hunk(raw_hunk)
		old_count = old_count or 0
		new_count = new_count or 0

		local old_chunk = {}
		for index = old_start, old_start + old_count - 1 do
			table.insert(old_chunk, old_lines[index] or "")
		end

		local new_chunk = {}
		for index = new_start, new_start + new_count - 1 do
			table.insert(new_chunk, new_lines[index] or "")
		end

		table.insert(hunks, {
			old_start = old_start,
			old_count = old_count,
			new_start = new_start,
			new_count = new_count,
			old_lines = old_chunk,
			new_lines = new_chunk,
		})
	end

	return hunks
end

local function tokenize(line)
	local tokens = {}
	local index = 1

	while index <= #line do
		local start_index = index
		local char = line:sub(index, index)
		local class

		if char:match("[%w_]") then
			class = "word"
		elseif char:match("%s") then
			class = "space"
		else
			class = "punct"
		end

		index = index + 1
		while index <= #line do
			local next_char = line:sub(index, index)
			local next_class
			if next_char:match("[%w_]") then
				next_class = "word"
			elseif next_char:match("%s") then
				next_class = "space"
			else
				next_class = "punct"
			end

			if next_class ~= class then
				break
			end

			index = index + 1
		end

		table.insert(tokens, {
			text = line:sub(start_index, index - 1),
			start_col = start_index - 1,
			end_col = index - 1,
		})
	end

	return tokens
end

local function merge_ranges(ranges)
	table.sort(ranges, function(a, b)
		return a[1] < b[1]
	end)

	local merged = {}
	for _, range in ipairs(ranges) do
		local last = merged[#merged]
		if last and range[1] <= last[2] then
			last[2] = math.max(last[2], range[2])
		else
			table.insert(merged, { range[1], range[2] })
		end
	end

	return merged
end

local function token_diff_ranges(old_line, new_line)
	if old_line == new_line then
		return {}, {}
	end

	local old_tokens = tokenize(old_line)
	local new_tokens = tokenize(new_line)
	local old_text = {}
	local new_text = {}

	for _, token in ipairs(old_tokens) do
		table.insert(old_text, token.text)
	end
	for _, token in ipairs(new_tokens) do
		table.insert(new_text, token.text)
	end

	local hunks = compute_hunks(old_text, new_text)
	local old_ranges = {}
	local new_ranges = {}

	for _, token_hunk in ipairs(hunks) do
		for index = token_hunk.old_start, token_hunk.old_start + token_hunk.old_count - 1 do
			local token = old_tokens[index]
			if token and token.start_col ~= token.end_col then
				table.insert(old_ranges, { token.start_col, token.end_col })
			end
		end

		for index = token_hunk.new_start, token_hunk.new_start + token_hunk.new_count - 1 do
			local token = new_tokens[index]
			if token and token.start_col ~= token.end_col then
				table.insert(new_ranges, { token.start_col, token.end_col })
			end
		end
	end

	return merge_ranges(old_ranges), merge_ranges(new_ranges)
end

local function virt_line_chunks(line, word_ranges, selected, virtual_cursor)
	local line_hl = "LiveDiffDelete"
	local word_hl = "LiveDiffDeleteWord"
	if selected then
		line_hl = "LiveDiffSelectedDelete"
		word_hl = "LiveDiffSelectedDeleteWord"
	elseif virtual_cursor then
		line_hl = "LiveDiffVirtualCursorDelete"
		word_hl = "LiveDiffVirtualCursorDeleteWord"
	end

	if #word_ranges == 0 then
		return { { line, line_hl } }
	end

	local chunks = {}
	local col = 0
	for _, range in ipairs(word_ranges) do
		if range[1] > col then
			table.insert(chunks, { line:sub(col + 1, range[1]), line_hl })
		end
		table.insert(chunks, { line:sub(range[1] + 1, range[2]), word_hl })
		col = range[2]
	end

	if col < #line then
		table.insert(chunks, { line:sub(col + 1), line_hl })
	end

	if #chunks == 0 then
		return { { "", line_hl } }
	end

	return chunks
end

local function word_ranges_for_hunk(hunk)
	local old_ranges = {}
	local new_ranges = {}
	local paired_count = math.min(hunk.old_count, hunk.new_count)

	for index = 1, paired_count do
		old_ranges[index], new_ranges[index] = token_diff_ranges(hunk.old_lines[index] or "", hunk.new_lines[index] or "")
	end

	return old_ranges, new_ranges
end

local function hunk_key(hunk)
	return table.concat({
		tostring(hunk.old_start),
		tostring(hunk.old_count),
		tostring(hunk.new_start),
		tostring(hunk.new_count),
		table.concat(hunk.old_lines, "\n"),
		table.concat(hunk.new_lines, "\n"),
	}, "\0")
end

local function render_hunk(bufnr, hunk, selected)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local row

	if hunk.new_count == 0 then
		-- For pure deletions, vim.diff reports new_start as the line before the
		-- deletion. Anchor the virtual deleted lines above the next real line so
		-- deleted lines that were adjacent to that line still look adjacent.
		row = math.min(math.max(hunk.new_start, 0), math.max(line_count - 1, 0))
	else
		row = math.min(math.max(hunk.new_start - 1, 0), math.max(line_count - 1, 0))
	end

	if hunk.new_count == 0 and line_count > 0 then
		local sign_row = math.min(row, line_count - 1)
		vim.api.nvim_buf_set_extmark(bufnr, namespace, sign_row, 0, {
			sign_text = "┃",
			sign_hl_group = selected and "LiveDiffSelectedHunkMarker" or "LiveDiffHunkMarker",
			right_gravity = false,
		})
	end

	local old_word_ranges, new_word_ranges = word_ranges_for_hunk(hunk)
	local virt_lines = {}
	local item = state[bufnr]
	local virtual_cursor = item and item.virtual_cursor
	local cursor_on_deleted_block = virtual_cursor and virtual_cursor.key == hunk.key
	for index, line in ipairs(hunk.old_lines) do
		if line ~= "" then
			table.insert(virt_lines, virt_line_chunks(line, old_word_ranges[index] or {}, selected, cursor_on_deleted_block))
		end
	end

	if #virt_lines > 0 then
		vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
			virt_lines = virt_lines,
			virt_lines_above = true,
			right_gravity = false,
		})
	end

	if hunk.new_count > 0 then
		for offset = 0, hunk.new_count - 1 do
			local hl_row = hunk.new_start - 1 + offset
			if hl_row >= 0 and hl_row < line_count then
				vim.api.nvim_buf_set_extmark(bufnr, namespace, hl_row, 0, {
					line_hl_group = selected and "LiveDiffSelectedAdd" or "LiveDiffAdd",
					sign_text = "┃",
					sign_hl_group = selected and "LiveDiffSelectedHunkMarker" or "LiveDiffHunkMarker",
					right_gravity = false,
				})

				for _, range in ipairs(new_word_ranges[offset + 1] or {}) do
					vim.api.nvim_buf_set_extmark(bufnr, namespace, hl_row, range[1], {
						end_col = range[2],
						hl_group = selected and "LiveDiffSelectedAddWord" or "LiveDiffAddWord",
						priority = 120,
						right_gravity = false,
					})
				end
			end
		end
	end
end

local update_real_cursor_visibility
local disable_buffer

local function render(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local item = state[bufnr]
	if not item or not item.enabled then
		return
	end

	vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
	item.hunks = compute_hunks(item.base_lines, current_lines(bufnr))

	local selected_key_still_exists = false
	local hunk_id_indexes = {}
	local hunk_id_count = 0
	for index, hunk in ipairs(item.hunks) do
		hunk.internal_index = index
		hunk.key = hunk_key(hunk)
		hunk.id = but_hunk_id(item.root, item.pathspec, hunk)
		local semantic_id = hunk.id or hunk.key
		if not hunk_id_indexes[semantic_id] then
			hunk_id_count = hunk_id_count + 1
			hunk_id_indexes[semantic_id] = hunk_id_count
		end
		hunk.index = hunk_id_indexes[semantic_id]
		hunk.count = hunk_id_count
		hunk.metadata = item.metadata[hunk.key]
		if hunk.key == item.selected_key then
			selected_key_still_exists = true
		end
	end

	item.hunk_count = hunk_id_count
	for _, hunk in ipairs(item.hunks) do
		hunk.count = hunk_id_count
	end

	if item.selected_key and not selected_key_still_exists then
		item.selected_key = nil
	end

	if item.virtual_cursor then
		local virtual_cursor_still_exists = false
		for _, hunk in ipairs(item.hunks) do
			if hunk.key == item.virtual_cursor.key then
				virtual_cursor_still_exists = true
				break
			end
		end
		if not virtual_cursor_still_exists then
			item.virtual_cursor = nil
		end
	end

	for _, hunk in ipairs(item.hunks) do
		render_hunk(bufnr, hunk, hunk.key == item.selected_key)
	end

	update_real_cursor_visibility()
end

local function schedule_render(bufnr)
	local item = state[bufnr]
	if not item or not item.enabled then
		return
	end

	if item.timer then
		item.timer:stop()
		item.timer:close()
	end

	item.timer = vim.uv.new_timer()
	item.timer:start(config.debounce_ms, 0, function()
		vim.schedule(function()
			render(bufnr)
		end)
	end)
end

local function normal_bg()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	if normal and normal.bg then
		return normal.bg
	end

	return "#000000"
end

update_real_cursor_visibility = function()
	local current_bufnr = vim.api.nvim_get_current_buf()
	local current_winid = vim.api.nvim_get_current_win()
	local item = state[current_bufnr]
	local should_hide = item and item.enabled and item.virtual_cursor ~= nil

	-- 'guicursor' is global, so restore it when leaving the window whose
	-- virtual cursor required hiding the real cursor.
	if cursor_hidden and (not should_hide or hidden_cursor_winid ~= current_winid) then
		if saved_guicursor then
			vim.o.guicursor = saved_guicursor
		end
		if hidden_cursor_winid and vim.api.nvim_win_is_valid(hidden_cursor_winid) then
			vim.api.nvim_set_option_value("cursorline", saved_cursorline, { win = hidden_cursor_winid })
		end
		saved_guicursor = nil
		saved_cursorline = nil
		hidden_cursor_winid = nil
		cursor_hidden = false
	end

	if should_hide and not cursor_hidden then
		saved_guicursor = vim.o.guicursor
		saved_cursorline = vim.api.nvim_get_option_value("cursorline", { win = current_winid })
		hidden_cursor_winid = current_winid
		vim.api.nvim_set_option_value("cursorline", false, { win = current_winid })
		vim.api.nvim_set_hl(0, "LiveDiffHiddenCursor", { fg = normal_bg(), bg = normal_bg(), blend = 100 })
		vim.o.guicursor = "n-v-c:block-LiveDiffHiddenCursor/lCursor"
		cursor_hidden = true
	end
end

local function set_highlights()
	vim.api.nvim_set_hl(0, "LiveDiffDelete", { link = "DiffDelete", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffAdd", { link = "DiffAdd", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffDeleteWord", { bg = "#7a3030", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffAddWord", { bg = "#496a3a", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffSelectedDelete", { bg = "#7a3f55", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffSelectedAdd", { bg = "#4f684b", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffSelectedDeleteWord", { bg = "#a54242", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffSelectedAddWord", { bg = "#6d8f4b", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffVirtualCursorDelete", { bg = "#5f4b7a", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffVirtualCursorDeleteWord", { bg = "#8a5fb3", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffHunkMarker", { fg = "#7f849c", bg = "NONE", default = true })
	vim.api.nvim_set_hl(0, "LiveDiffSelectedHunkMarker", { fg = "#f5c2e7", bg = "NONE", default = true })
end

local function should_enable(bufnr)
	if vim.api.nvim_get_option_value("buftype", { buf = bufnr }) ~= "" then
		return false
	end

	if not bufname(bufnr) then
		return false
	end

	return true
end

local function enable_buffer(bufnr, opts)
	opts = opts or {}
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) or not should_enable(bufnr) then
		return false
	end

	local path = bufname(bufnr)
	local root, root_err = repo_root_for_buffer(bufnr)
	if not root then
		if not opts.silent then
			notify("Not in a git repo: " .. root_err, vim.log.levels.WARN)
		end
		return false
	end

	local pathspec = relative_path(root, path)
	if not pathspec then
		if not opts.silent then
			notify("Buffer is not inside the git repo", vim.log.levels.WARN)
		end
		return false
	end

	disable_buffer(bufnr)

	state[bufnr] = {
		enabled = true,
		root = root,
		pathspec = pathspec,
		base_lines = base_lines(root, pathspec),
		hunks = {},
		metadata = {},
		selected_key = nil,
		virtual_cursor = nil,
	}

	vim.keymap.set("n", "j", function()
		require("live_diff").move_down()
	end, { buffer = bufnr, desc = "Live diff move down" })
	vim.keymap.set("n", "k", function()
		require("live_diff").move_up()
	end, { buffer = bufnr, desc = "Live diff move up" })

	vim.api.nvim_buf_attach(bufnr, false, {
		on_lines = function(_, attached_bufnr)
			schedule_render(attached_bufnr)
		end,
		on_detach = function(_, attached_bufnr)
			state[attached_bufnr] = nil
			vim.schedule(update_real_cursor_visibility)
		end,
	})

	render(bufnr)
	return true
end

function disable_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if item and item.timer then
		item.timer:stop()
		item.timer:close()
	end

	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
		pcall(vim.keymap.del, "n", "j", { buffer = bufnr })
		pcall(vim.keymap.del, "n", "k", { buffer = bufnr })
	end

	state[bufnr] = nil
	update_real_cursor_visibility()
end

function M.enable()
	global_enabled = true
	local enabled_any = false
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and should_enable(bufnr) then
			enabled_any = enable_buffer(bufnr, { silent = true }) or enabled_any
		end
	end
	return enabled_any
end

function M.disable()
	global_enabled = false
	for bufnr in pairs(state) do
		disable_buffer(bufnr)
	end
	return true
end

function M.toggle()
	if global_enabled then
		M.disable()
		return false
	end

	M.enable()
	return true
end

function M.reload(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	but_diff_cache = {}
	if not item or not item.enabled then
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
		end
		if not global_enabled then
			return false
		end
		return enable_buffer(bufnr, { silent = true })
	end

	item.base_lines = base_lines(item.root, item.pathspec)
	item.selected_key = nil
	item.virtual_cursor = nil
	render(bufnr)
	return true
end

function M.is_enabled()
	return global_enabled
end

function M.get_hunks(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if not item then
		return {}
	end

	return vim.deepcopy(item.hunks)
end

local function hunk_at_line(bufnr, line)
	local item = state[bufnr]
	if not item then
		return nil
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	for _, hunk in ipairs(item.hunks) do
		if hunk.new_count > 0 then
			local start_line = hunk.new_start
			local end_line = hunk.new_start + hunk.new_count - 1
			if line >= start_line and line <= end_line then
				return hunk
			end
		elseif line_count > 0 then
			local anchor_line = math.min(math.max(hunk.new_start, 1), line_count)
			if line == anchor_line then
				return hunk
			end
		end
	end

	return nil
end

local function hunk_by_key(item, key)
	for _, hunk in ipairs(item.hunks) do
		if hunk.key == key then
			return hunk
		end
	end

	return nil
end

function M.hunk_at_cursor(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if not item then
		return nil
	end

	if item.virtual_cursor then
		local virtual_hunk = hunk_by_key(item, item.virtual_cursor.key)
		if virtual_hunk then
			return vim.deepcopy(virtual_hunk)
		end
	end

	local cursor_line = math.max(vim.api.nvim_win_get_cursor(0)[1], 1)
	local hunk = hunk_at_line(bufnr, cursor_line)
	if not hunk then
		return nil
	end

	return vim.deepcopy(hunk)
end

function M.select_hunk(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if not item then
		return nil
	end

	local hunk
	if item.virtual_cursor then
		hunk = hunk_by_key(item, item.virtual_cursor.key)
	else
		local cursor_line = math.max(vim.api.nvim_win_get_cursor(0)[1], 1)
		hunk = hunk_at_line(bufnr, cursor_line)
	end
	if not hunk then
		item.selected_key = nil
		render(bufnr)
		return nil
	end

	item.selected_key = hunk.key
	render(bufnr)
	return vim.deepcopy(hunk)
end

function M.clear_selection(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if not item then
		return false
	end

	item.selected_key = nil
	render(bufnr)
	return true
end

function M.selected_hunk(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if not item or not item.selected_key then
		return nil
	end

	for _, hunk in ipairs(item.hunks) do
		if hunk.key == item.selected_key then
			return vim.deepcopy(hunk)
		end
	end

	return nil
end

function M.current_hunk_id(bufnr)
	local selected = M.selected_hunk(bufnr)
	if selected and selected.id then
		return selected.id
	end

	local hunk = M.hunk_at_cursor(bufnr)
	return hunk and hunk.id or nil
end

function M.status_hunk_id()
	local bufnr = vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if not item or vim.tbl_isempty(item.hunks) then
		return ""
	end

	local hunk = M.selected_hunk(bufnr) or M.hunk_at_cursor(bufnr)
	if not hunk or not hunk.id then
		return ""
	end

	return string.format("%s %d/%d", hunk.id, hunk.index, item.hunk_count or #item.hunks)
end

local function hunk_anchor_line(bufnr, hunk)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count == 0 then
		return 1
	end

	local line = hunk.new_start
	if hunk.new_count == 0 then
		line = line + 1
	end

	return math.min(math.max(line, 1), line_count)
end

local function normal_move(command)
	vim.cmd.normal({ command, bang = true })
end

local function move_down_once(bufnr)
	local item = state[bufnr]
	if not item then
		normal_move("gj")
		return false
	end

	if item.virtual_cursor then
		local hunk = hunk_by_key(item, item.virtual_cursor.key)
		item.virtual_cursor = nil
		if hunk then
			vim.api.nvim_win_set_cursor(0, { hunk_anchor_line(bufnr, hunk), 0 })
		end
		render(bufnr)
		return true
	end

	local current_line = math.max(vim.api.nvim_win_get_cursor(0)[1], 1)
	for _, hunk in ipairs(item.hunks) do
		if hunk.old_count > 0 and hunk_anchor_line(bufnr, hunk) == current_line + 1 then
			item.virtual_cursor = { key = hunk.key }
			render(bufnr)
			return true
		end
	end

	normal_move("gj")
	return false
end

local function move_up_once(bufnr)
	local item = state[bufnr]
	if not item then
		normal_move("gk")
		return false
	end

	if item.virtual_cursor then
		local hunk = hunk_by_key(item, item.virtual_cursor.key)
		item.virtual_cursor = nil
		if hunk then
			local previous_line = math.max(hunk_anchor_line(bufnr, hunk) - 1, 1)
			vim.api.nvim_win_set_cursor(0, { previous_line, 0 })
		end
		render(bufnr)
		return true
	end

	local current_line = math.max(vim.api.nvim_win_get_cursor(0)[1], 1)
	for _, hunk in ipairs(item.hunks) do
		if hunk.old_count > 0 and hunk_anchor_line(bufnr, hunk) == current_line then
			item.virtual_cursor = { key = hunk.key }
			render(bufnr)
			return true
		end
	end

	normal_move("gk")
	return false
end

function M.move_down(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _ = 1, vim.v.count1 do
		move_down_once(bufnr)
	end
end

function M.move_up(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _ = 1, vim.v.count1 do
		move_up_once(bufnr)
	end
end

local function jump_hunk(bufnr, direction)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local item = state[bufnr]
	if not item or vim.tbl_isempty(item.hunks) then
		return false
	end

	local current = vim.api.nvim_win_get_cursor(0)[1]
	local target

	if direction > 0 then
		for _, hunk in ipairs(item.hunks) do
			if hunk.new_start > current then
				target = hunk
				break
			end
		end
	else
		for index = #item.hunks, 1, -1 do
			local hunk = item.hunks[index]
			if hunk.new_start < current then
				target = hunk
				break
			end
		end
	end

	if not target then
		return false
	end

	item.virtual_cursor = nil
	local line = hunk_anchor_line(bufnr, target)
	vim.api.nvim_win_set_cursor(0, { line, 0 })
	if target.old_count > 0 then
		item.virtual_cursor = { key = target.key }
	end
	render(bufnr)
	return true
end

function M.next_hunk(bufnr)
	return jump_hunk(bufnr, 1)
end

function M.prev_hunk(bufnr)
	return jump_hunk(bufnr, -1)
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
	set_highlights()

	local group = vim.api.nvim_create_augroup("LiveDiffAutoEnable", { clear = true })
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = group,
		callback = function(event)
			vim.schedule(function()
				if global_enabled and vim.api.nvim_buf_is_valid(event.buf) and should_enable(event.buf) then
					enable_buffer(event.buf, { silent = true })
				end
			end)
		end,
	})

	vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
		group = group,
		callback = function()
			-- Run after other enter autocmds so cursorline ends in the state
			-- required by the active virtual cursor.
			vim.schedule(update_real_cursor_visibility)
		end,
	})

	if config.auto_enable then
		vim.schedule(function()
			M.enable()
		end)
	end
end

return M
