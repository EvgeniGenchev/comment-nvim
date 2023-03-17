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
	["c"] = "//"
}


local function strip(s)
   return s:match( "^%s*(.-)%s*$" )
end

local function isCommented(line, commentSign)

	local commFlag = false


	if line:sub(1, #commentSign) == commentSign then
		commFlag = true
	end
	return commFlag
end

local function count_indent(str)
	local count_tab = 0
	local count_sp = 0


	for i = 1, #str do
		local c = str:sub(i,i)

		if (c ~= "\t") then
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
	local lines = {}
	local filetype = bo.filetype
	local commentSign = languages[filetype]

	for i = start_line, end_line do

		local line = vim.fn.getline(i)
		local n_tabs, n_spaces = count_indent(line)
		local spaces = string.rep(" ", n_spaces)
		local tabs = string.rep("\t", n_tabs)

		local sline = strip(line)

		if commentSign ~= nil then
			if isCommented(sline, commentSign) then
				line = tabs .. spaces .. sline:sub(#commentSign+2)
			else
				line = tabs .. spaces .. commentSign .. " " .. sline
			end
		else
			print("Language [" .. filetype ..  "] is not supproted")
		end
    table.insert(lines, line)
  end
  vim.fn.setline(start_line, lines)
end


local function comment()

	local filetype = bo.filetype
	local line = a.nvim_get_current_line()
	local sline = strip(line)
	local n_tabs, n_spaces = count_indent(line)
	local spaces = string.rep(" ", n_spaces)
	local tabs = string.rep("\t", n_tabs)
	local commentSign = languages[filetype]

	if commentSign ~= nil then
		if isCommented(sline, commentSign) then
			a.nvim_set_current_line(
			tabs .. spaces .. sline:sub(#commentSign+2))
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

