local config = require("kb.config")
local R = {}

local telescope = require("telescope.builtin")
local actions = require("telescope.actions")
local state = require("telescope.actions.state")
-- Configure root directory
local root = config.options.root_dir
-- local vim = vim

local function search(search_pattern, folder)
	local files = {}
	local cmd = "find " .. root .. (folder and ("/" .. folder) or "") .. ' -type f -iname "' .. search_pattern .. '"'
	local handle, err = io.popen(cmd)
	-- Open Pipe
	if not handle then
		print("Error executing command", err)
		return files
	end
	-- Read
	local result = handle:read("*a")
	local success, close_err = handle:close()
	if not success then
		print("Error closing pipe:", close_err)
	end
	-- Process result
	for file in result:gmatch("[^\r\n]+") do
		table.insert(files, file)
	end
	return files
end

local function get_linked_text()
	local line = vim.fn.getline(".")
	local cursor_loc = vim.fn.col(".")
	local pattern = "%[%[(.-)%]%]"
	local texts = {}
	for text in line:gmatch(pattern) do
		local match_start, match_end = line:find("%[%[" .. text .. "%]%]")
		if match_start and match_end and match_start <= cursor_loc and cursor_loc <= match_end then
			table.insert(texts, text)
		end
	end
	return texts[1]
end

local function get()
	local text = get_linked_text()
	if text == nil then
		local mode = vim.fn.visualmode()
		if mode ~= "" then
			text = vim.fn.getreg("v")
		end
	end
	if text == "" or text == nil then
		text = vim.fn.expand("<cword>")
	end
	return text
end

local function create_new(path, name)
	local full_path
	if path ~= nil then
		full_path = vim.fn.fnamemodify(root .. "/" .. path .. "/" .. name, ":p")
	else
		full_path = vim.fn.fnamemodify(root .. "/" .. name, ":p")
	end
	local dir = vim.fn.fnamemodify(full_path, ":p:h")
	if not vim.fn.isdirectory(dir) then
		vim.fn.mkdir(dir, "p")
	end
	local file = io.open(full_path, "r")
	if file then
		print("File already exists")
		return file
	else
		file = io.open(full_path, "w")
		if not file then
			print("Failed to create file: " .. full_path)
			return
		end
		return file
	end
end

local function open_card(file)
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = 80,
		height = 20,
		col = 10,
		row = 10,
		anchor = "NW",
		style = "minimal",
		border = "rounded",
	})
	vim.api.nvim_buf_set_option(buf, "buftype", "")
	vim.api.nvim_buf_set_option(buf, "modifiable", true)
	vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
	vim.cmd("e " .. vim.fn.fnameescape(file))
	vim.api.nvim_command("normal! G")
end

local function picker(files, handler)
	telescope.find_files({
		prompt_title = "Select note",
		cwd = root,
		search_dirs = files,
		attach_mappings = function(prompt_bufnr, map)
			map("i", "<CR>", function()
				local selection = state.get_selected_entry()
				if selection then
					local file = selection.value
					print("Opening:", file)
					actions.close(prompt_bufnr)
					if handler then
						handler(file)
					end
				end
			end)
			return false
		end,
	})
end

function R.wikihover()
	local word = get()
	if word == nil or word == "" then
		print("Definition Not Found for Word: " .. word)
		return
	end
	local link_parts = vim.split(word, ":")
	local search_pattern = link_parts[#link_parts] .. ".md"
	local files
	local path
	if #link_parts == 1 then
		files = search(search_pattern)
	elseif #link_parts == 2 then
		path = link_parts[1]
		files = search(search_pattern, path)
	end

	if #files == 0 then
		local qprompt = "File not found would you like to create " .. search_pattern
		if path ~= nil then
			qprompt = qprompt .. "at path " .. path
		end
		qprompt = qprompt .. "? (Y/n): "
		vim.ui.input({ prompt = qprompt }, function(input)
			if input:lower() == "y" then
				local new_file = create_new(path, search_pattern)
				if new_file ~= nil then
					table.insert(files, new_file)
				end
			end
		end)
	end

	if #files == 1 then
		open_card(files[1])
	elseif #files > 1 then
		picker(files, open_card)
		--	if file ~= nil then
		--		open_card(file)
		--	end
	end
end

setup = function(user_opts)
	config.setup(user_opts)
end

return R
