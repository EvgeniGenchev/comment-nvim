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
	["sh"]         = { "#",   nil },
	["cpp"]        = { "//",  { "/*", "*/" } },
	["c"]          = { "//",  { "/*", "*/" } },
	["jsonc"]      = { "//",  { "/*", "*/" } },
	["javascript"] = { "//",  { "/*", "*/" } },
	["typescript"] = { "//",  { "/*", "*/" } },
	["rust"]       = { "//",  { "/*", "*/" } },
	["go"]         = { "//",  { "/*", "*/" } },
	["zig"]        = { "//",  nil },
	["nim"]        = { "#",   nil },
	["conf"]       = { "#",   nil },
	["dockerfile"] = { "#",   nil },
	["zsh"]        = { "#",   nil },
	["bash"]       = { "#",   nil },
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


-- Single line comment toggle (normal mode)
local function comment()
	local filetype = bo.filetype
	local lang = languages[filetype]

	if lang == nil then
		print("Language [" .. filetype .. "] is not supported")
		return
	end

	local single = lang[1]

	if single == nil then
		print("Language [" .. filetype .. "] has no single-line comment syntax")
		return
	end

	local line = a.nvim_get_current_line()
	local sline = strip(line)
	local n_tabs, n_spaces = count_indent(line)
	local spaces = string.rep(" ", n_spaces)
	local tabs = string.rep("\t", n_tabs)

	if isCommented(sline, single) then
		local uncommented = sline:sub(#single + 1)
		if uncommented:sub(1, 1) == " " then
			uncommented = uncommented:sub(2)
		end
		a.nvim_set_current_line(tabs .. spaces .. uncommented)
	else
		a.nvim_set_current_line(tabs .. spaces .. single .. " " .. sline)
	end
end


-- Check if a block of lines is wrapped in block comment delimiters
local function isBlockCommented(lines, open, close)
	if #lines < 2 then return false end
	return strip(lines[1]) == open and strip(lines[#lines]) == close
end


-- Apply single-line comments to a range of lines (used by commentMore)
local function applyLineComments(original_lines, single)
	-- Decide: comment or uncomment
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
		-- Find minimum indentation, ignoring empty lines
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
			if i == 1 or i == #original_lines then
				-- skip the open/close delimiter lines
			else
				table.insert(new_lines, line)
			end
		end
		return new_lines
	end

	-- Otherwise wrap with block comment delimiters on their own lines
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

	-- Merge user-provided language overrides
	if opts.languages then
		for key, value in pairs(opts.languages) do
			languages[key] = value
		end
	end

	-- Override threshold if provided
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
