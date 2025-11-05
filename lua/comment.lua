-- Plugin: comment-nvim
-- Author: EvgeniGenchev
-- License: MIT
-- Source: http://github.com/EvgeniGenchev/comment-nvim

local a = vim.api
local bo = vim.bo

local languages = {
	["lua"] = "--",
	["python"] = "#",
	["sh"] = "#",
	["cpp"] = "//",
	["c"] = "//",
	["jsonc"] = "//",
	["javascript"] = "//"
}


local function strip(s)
   return s:match( "^%s*(.-)%s*$" )
end

local function isCommented(line, commentSign)
	return line:sub(1, #commentSign) == commentSign
end

local function count_indent(str)
	local count_tab = 0
	local count_sp = 0


	for i = 1, #str do
		local c = str:sub(i,i)

		if (c ~= "	") then
			if (c ~= " ") then
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

local function commentMore()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")
	local filetype = bo.filetype
	local commentSign = languages[filetype]

	if commentSign == nil then
		print("Language [" .. filetype .. "] is not supported")
		return
	end

	-- Decide action: if any line is not commented, we comment all. Otherwise, uncomment all.
	local action = "uncomment"
	local original_lines = {}
	for i = start_line, end_line do
		local line = vim.fn.getline(i)
		table.insert(original_lines, line)
		local indent_str = line:match("^%s*")
		local content_part = line:sub(#indent_str + 1)
		if #strip(line) > 0 and content_part:sub(1, #commentSign) ~= commentSign then
			action = "comment"
		end
	end

	local new_lines = {}
	if action == "comment" then
		-- Find minimum indentation for alignment, ignoring empty lines
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

		-- Apply comment to all lines
		for _, line in ipairs(original_lines) do
			table.insert(new_lines, indent_prefix .. commentSign .. " " .. line:sub(min_indent + 1))
		end
	else -- Action is "uncomment"
		for _, line in ipairs(original_lines) do
			local indent_str = line:match("^%s*")
			local content_part = line:sub(#indent_str + 1)

			if content_part:sub(1, #commentSign) == commentSign then
				local uncommented_content = content_part:sub(#commentSign + 1)
				if uncommented_content:sub(1, 1) == " " then
					uncommented_content = uncommented_content:sub(2)
				end
				-- If the line is empty after uncommenting, make it truly empty.
				if #strip(uncommented_content) == 0 then
					table.insert(new_lines, "")
				else
					table.insert(new_lines, indent_str .. uncommented_content)
				end
			else
				table.insert(new_lines, line)
			end
		end
	end

	a.nvim_buf_set_lines(0, start_line - 1, end_line, false, new_lines)
end


local function comment()

	local filetype = bo.filetype
	local line = a.nvim_get_current_line()
	local sline = strip(line)
	local n_tabs, n_spaces = count_indent(line)
	local spaces = string.rep(" ", n_spaces)
	local tabs = string.rep("	", n_tabs)
	local commentSign = languages[filetype]

	if commentSign ~= nil then
		if isCommented(sline, commentSign) then
			local uncommented_sline = sline:sub(#commentSign + 1)
			if uncommented_sline:sub(1, 1) == " " then
				uncommented_sline = uncommented_sline:sub(2)
			end
			a.nvim_set_current_line(
			tabs .. spaces .. uncommented_sline)
		else
			a.nvim_set_current_line(
			tabs .. spaces .. commentSign .. " " .. sline)
		end
	else
		print("Language [" .. filetype ..  "] is not supproted")
	end

end


local function setup(opts)

	if not opts then
		opts = {}
	end

	local langs = {}

	if opts.languages then
		langs = opts.languages
	end

	for key, value in pairs(langs) do
		languages[key] = value
	end

	vim.cmd('command! Comment lua require("comment").comment()')
	a.nvim_set_keymap('n', '?', ':Comment<CR>', {noremap=true, silent=false})

	vim.cmd('command! -range CommentMore lua require("comment").commentMore()')
	a.nvim_set_keymap('v', '?', ':CommentMore<CR>', {noremap=true, silent=false})
end

return {
	comment = comment,
	setup = setup,
	commentMore = commentMore
}

