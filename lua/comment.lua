-- Plugin: comment-nvim
-- Author: EvgeniGenchev
-- License: MIT
-- Source: http://github.com/EvgeniGenchev/comment-nvim

local a = vim.api
local bo = vim.bo

local languages = {
	["lua"] = "--",
	["python"] = "#",
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

local function commentMore()
	local start_line = vim.fn.line("'<")
	local end_line = vim.fn.line("'>")
	local lines = {}
	local filetype = bo.filetype
	local commentSign = languages[filetype]

	for i = start_line, end_line do

		local line = vim.fn.getline(i)
		local _, n_spaces = line:gsub("^%s+", "")
		local spaces = string.rep(" ", n_spaces)
		local sline = strip(line)

		if isCommented(sline, commentSign) == 0 then
			line = spaces .. sline:sub(#commentSign+2)
		else
			line = spaces .. commentSign .. " " .. sline
		end
    table.insert(lines, line)
  end
  vim.fn.setline(start_line, lines)
end

local function comment()

	local line = a.nvim_get_current_line()
	local _, n_spaces = line:gsub("^%s+", "")
	local sline = strip(line)
	local spaces = string.rep(" ", n_spaces)
	local filetype = bo.filetype
	local commentSign = languages[filetype]

	if isCommented(sline, commentSign) then
		a.nvim_set_current_line(spaces .. sline:sub(#commentSign+2))
	else
		a.nvim_set_current_line(spaces .. commentSign .. " " .. sline)
	end
end


local function setup()
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

