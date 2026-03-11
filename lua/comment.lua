-- Plugin: comment-nvim
-- Author: EvgeniGenchev
-- License: MIT
-- Source: http://github.com/EvgeniGenchev/comment-nvim

local a = vim.api
local bo = vim.bo

-- Each language entry: { single, multi }
-- single: single-line comment prefix string, or nil
-- multi: { open, close } block comment delimiters, or nil
local languages = {
	["lua"]        = { "--",  { "--[[", "]]" } },
	["python"]     = { "#",   { '"""', '"""' } },
	["c"]          = { "//",  { "/*", "*/" } },
	["cpp"]        = { "//",  { "/*", "*/" } },
	["javascript"] = { "//",  { "/*", "*/" } },
	["html"]       = { nil,   { "<!--", "-->" } },
	["css"]        = { nil,   { "/*", "*/" } },
	["java"]       = { "//",  { "/*", "*/" } },
}

local threshold = 4  -- use block comments when selection >= this many lines


local function strip(s)
	return s:match("^%s*(.-)%s*$")
end

local function isCommented(line, commentSign)
	return line:sub(1, #commentSign) == commentSign
end

local function count_indent(str)
	local count_tab = 0
	local count_sp = 0
	for i = 1, #str do
		local c = str:sub(i, i)
		if c ~= "\t" then
			if c ~= " " then
				break
			else
				count_sp = count_sp + 1
			end
		else
			count_tab = count_tab + 1
		end
	end
	return count_tab, count_sp
end


local function find_matching_close(from_line, open, close)
	local total = a.nvim_buf_line_count(0)
	local depth = 1
	for i = from_line + 1, total do
		local s = strip(vim.fn.getline(i))
		if s == open  then depth = depth + 1 end
		if s == close then
			depth = depth - 1
			if depth == 0 then return i end
		end
	end
	return nil
end

-- Scan backward from `from_line` (1-indexed) to find the matching open delimiter.
-- Uses depth counting to handle nesting. Returns the 1-indexed line number or nil.
local function find_matching_open(from_line, open, close)
	local depth = 1
	for i = from_line - 1, 1, -1 do
		local s = strip(vim.fn.getline(i))
		if s == close then depth = depth + 1 end
		if s == open  then
			depth = depth - 1
			if depth == 0 then return i end
		end
	end
	return nil
end


-- Single line comment toggle (normal mode)
local function comment()
	local filetype = bo.filetype
	local lang = languages[filetype]

	if lang == nil then
		print("Language [" .. filetype .. "] is not supported")
		return
	end

	local single = lang[1]
	local multi  = lang[2]

	local cur_line_nr = a.nvim_win_get_cursor(0)[1]
	local line  = a.nvim_get_current_line()
	local sline = strip(line)
	local n_tabs, n_spaces = count_indent(line)
	local indent = string.rep("\t", n_tabs) .. string.rep(" ", n_spaces)

	-- If multi exists, check if the current line is a bare open or close delimiter.
	-- If so, find the matching pair and remove both delimiter lines.
	if multi ~= nil then
		local open, close = multi[1], multi[2]

		if sline == open then
			local match = find_matching_close(cur_line_nr, open, close)
			if match ~= nil then
				-- Remove close first (higher index), then open
				a.nvim_buf_set_lines(0, match - 1, match, false, {})
				a.nvim_buf_set_lines(0, cur_line_nr - 1, cur_line_nr, false, {})
				return
			end
		end

		if sline == close then
			local match = find_matching_open(cur_line_nr, open, close)
			if match ~= nil then
				-- Remove close first (higher index), then open (lower index)
				a.nvim_buf_set_lines(0, cur_line_nr - 1, cur_line_nr, false, {})
				a.nvim_buf_set_lines(0, match - 1, match, false, {})
				return
			end
		end
	end

	-- Otherwise: normal single-line toggle behaviour
	if single ~= nil then
		if isCommented(sline, single) then
			local uncommented = sline:sub(#single + 1)
			if uncommented:sub(1, 1) == " " then uncommented = uncommented:sub(2) end
			a.nvim_set_current_line(indent .. uncommented)
		else
			a.nvim_set_current_line(indent .. single .. " " .. sline)
		end
	elseif multi ~= nil then
		local open, close = multi[1], multi[2]
		-- Toggle inline block: /* content */ on a single line
		if sline:sub(1, #open) == open and sline:sub(-#close) == close then
			local uncommented = sline:sub(#open + 1, -(#close + 1))
			if uncommented:sub(1, 1) == " " then uncommented = uncommented:sub(2) end
			if uncommented:sub(-1) == " " then uncommented = uncommented:sub(1, -2) end
			a.nvim_set_current_line(indent .. uncommented)
		else
			a.nvim_set_current_line(indent .. open .. " " .. sline .. " " .. close)
		end
	else
		print("Language [" .. filetype .. "] has no supported comment syntax")
	end
end


-- Check if a block of lines is wrapped in block comment delimiters
local function isBlockCommented(lines, open, close)
	if #lines < 2 then return false end
	return strip(lines[1]) == open and strip(lines[#lines]) == close
end


-- Apply single-line comments to a range of lines (used by commentMore)
local function applyLineComments(original_lines, single)
	local action = "uncomment"
	for _, line in ipairs(original_lines) do
		local indent_str = line:match("^%s*")
		local content_part = line:sub(#indent_str + 1)
		if #strip(line) > 0 and content_part:sub(1, #single) ~= single then
			action = "comment"
		end
	end

	local new_lines = {}

	if action == "comment" then
		local min_indent = -1
		for _, line in ipairs(original_lines) do
			if #strip(line) > 0 then
				local indent_str = line:match("^%s*")
				local current_indent = #indent_str
				if min_indent == -1 or current_indent < min_indent then
					min_indent = current_indent
				end
			end
		end
		if min_indent == -1 then min_indent = 0 end
		local indent_prefix = string.rep(" ", min_indent)

		for _, line in ipairs(original_lines) do
			table.insert(new_lines, indent_prefix .. single .. " " .. line:sub(min_indent + 1))
		end
	else
		for _, line in ipairs(original_lines) do
			local indent_str = line:match("^%s*")
			local content_part = line:sub(#indent_str + 1)
			if content_part:sub(1, #single) == single then
				local uncommented = content_part:sub(#single + 1)
				if uncommented:sub(1, 1) == " " then
					uncommented = uncommented:sub(2)
				end
				if #strip(uncommented) == 0 then
					table.insert(new_lines, "")
				else
					table.insert(new_lines, indent_str .. uncommented)
				end
			else
				table.insert(new_lines, line)
			end
		end
	end

	return new_lines
end


-- Apply block comments to a range of lines (used by commentMore)
local function applyBlockComment(original_lines, open, close)
	if isBlockCommented(original_lines, open, close) then
		local new_lines = {}
		for i, line in ipairs(original_lines) do
			if i ~= 1 and i ~= #original_lines then
				table.insert(new_lines, line)
			end
		end
		return new_lines
	end

	local indent_prefix = ""
	for _, line in ipairs(original_lines) do
		if #strip(line) > 0 then
			indent_prefix = line:match("^%s*")
			break
		end
	end

	local new_lines = {}
	table.insert(new_lines, indent_prefix .. open)
	for _, line in ipairs(original_lines) do
		table.insert(new_lines, line)
	end
	table.insert(new_lines, indent_prefix .. close)

	return new_lines
end


-- Visual range comment toggle (visual mode)
local function commentMore()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")
	local filetype = bo.filetype
	local lang = languages[filetype]

	if lang == nil then
		print("Language [" .. filetype .. "] is not supported")
		return
	end

	local single = lang[1]
	local multi  = lang[2]
	local line_count = end_line - start_line + 1

	local original_lines = {}
	for i = start_line, end_line do
		table.insert(original_lines, vim.fn.getline(i))
	end

	local new_lines

	-- Use block if: multi exists AND (no single OR line count >= threshold)
	if multi ~= nil and (single == nil or line_count >= threshold) then
		new_lines = applyBlockComment(original_lines, multi[1], multi[2])
	elseif single ~= nil then
		new_lines = applyLineComments(original_lines, single)
	else
		print("Language [" .. filetype .. "] has no supported comment syntax")
		return
	end

	a.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
end


local function setup(opts)
	if not opts then
		opts = {}
	end

	if opts.languages then
		for key, value in pairs(opts.languages) do
			languages[key] = value
		end
	end

	if opts.threshold then
		threshold = opts.threshold
	end

	vim.cmd('command! Comment lua require("comment").comment()')
	a.nvim_set_keymap('n', '?', ':Comment<CR>', { noremap = true, silent = false })

	vim.cmd('command! -range CommentMore lua require("comment").commentMore()')
	a.nvim_set_keymap('v', '?', ':CommentMore<CR>', { noremap = true, silent = false })
end

return {
	comment     = comment,
	commentMore = commentMore,
	setup       = setup,
}
