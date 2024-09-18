local O = {}

O.options = {
	root_dir = "~/kb",
}

function O.setup(user_opts)
	O.options = vim.tbl_deep_extend("force", options, user_opts or {})
end

return O
