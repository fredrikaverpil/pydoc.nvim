local M = {}

-- Default configuration.
M.config = {
	command = "PyDoc",
	window = {
		type = "split", -- split or vsplit
	},
	highlighting = {
		language = "markdown",
	},
	picker = {
		type = "native", -- native or snacks
		snacks_options = {
			layout = {
				layout = {
					height = 0.8,
					width = 0.9, -- Take up 90% of the total width (adjust as needed)
					box = "horizontal", -- Horizontal layout (input and list on the left, preview on the right)
					{ -- Left side (input and list)
						box = "vertical",
						width = 0.3, -- List and input take up 30% of the width
						border = "rounded",
						{ win = "input", height = 1, border = "bottom" },
						{ win = "list", border = "none" },
					},
					{ win = "preview", border = "rounded", width = 0.7 }, -- Preview window takes up 70% of the width
				},
			},
			win = {
				preview = {
					wo = { wrap = true },
				},
			},
		},
	},
}

-- Set up syntax highlighting
vim.treesitter.language.register(M.config.highlighting.language, { "pydoc" })

-- Check if python is available
local function check_requirements()
	if vim.fn.executable("python") == 0 then
		return false, "'python' binary not found in PATH"
	end

	-- Test pydoc functionality
	local test = vim.fn.system("python -m pydoc --help")
	if vim.v.shell_error ~= 0 then
		return false, "'python -m pydoc --help' command failed. Please run :checkhealth pydoc for more information"
	end

	return true, nil
end

-- Set up the plugin with user config
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create user command
	vim.api.nvim_create_user_command(M.config.command, function(args)
		-- Check requirements
		local ok, err = check_requirements()
		if not ok then
			vim.notify(string.format("pydoc.nvim: %s", err), vim.log.levels.ERROR)
			return
		end

		-- if args were passed, show documentation directly
		if args.args ~= nil and args.args ~= "" then
			M.show_documentation(args.args)
			return
		end

		if M.config.picker.type == "native" then
			M.show_native_picker()
		elseif M.config.picker.type == "telescope" then
			M.show_telescope_picker()
		elseif M.config.picker.type == "snacks" then
			M.show_snacks_picker()
		else
			vim.notify("Picker not implemented: " .. M.config.picker.type, vim.log.levels.ERROR)
		end
	end, { nargs = "?" })
end

---Get standard library packages from pydoc
---@returns table<string>
local function get_pydoc_modules()
	local pydoc_modules = vim.fn.systemlist("python -m pydoc modules")
	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to get package list using 'python -m pydoc modules'", vim.log.levels.ERROR)
		return {}
	end
	return pydoc_modules
end

-- Function to convert the Python modules output to a Lua table
local function format_pydoc_modules_output(input)
	local modules = {}

	-- Flag to track if we've started processing modules
	local started = false

	for _, line in ipairs(input) do
		-- Skip until we find a line starting with "__"
		if line:match("^__") then
			started = true
		end

		-- Skip empty lines and the final help text
		if started and line ~= "" then
			-- Stop when we reach the end help message:
			-- "Enter any module name to get more help.  Or, type "modules spam" to search
			-- for modules whose name or summary contain the string "spam"."
			if line:match("^Enter any module") then
				break
			end

			-- Split the line by whitespace and extract module names
			for module in line:gmatch("([^%s]+)%s*") do
				-- Skip common text patterns that aren't module names
				if
					not module:match("test_sqlite3:")
					and not module:match("Please wait")
					and not module:match("for modules whose")
				then
					table.insert(modules, module)
				end
			end
		end
	end

	-- Sort the modules alphabetically
	table.sort(modules)

	return modules
end

-- Cache for package list
local package_cache = nil
local package_cache_time = 0
local package_cache_cwd = vim.fn.getcwd()
local CACHE_DURATION = 300 -- 5 minutes

--- Get list of packages
---@return table<string>
local function get_packages()
	-- Check cache
	local current_time = os.time()
	if
		package_cache
		and (current_time - package_cache_time) < CACHE_DURATION
		and package_cache_cwd == vim.fn.getcwd()
	then
		return package_cache
	end

	local pydoc_modules = get_pydoc_modules()
	local all_modules = format_pydoc_modules_output(pydoc_modules)

	-- Update cache
	package_cache = vim.fn.uniq(all_modules)
	package_cache_time = current_time

	return all_modules
end

-- Show Neovim-native picker
function M.show_native_picker()
	-- Show native picker with packages
	vim.ui.select(get_packages(), {
		prompt = "Select Python module:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			M.show_documentation(choice)
		end
	end)
end

-- Show telescope picker
function M.show_telescope_picker()
	local action_state = require("telescope.actions.state")
	local finders = require("telescope.finders")
	local pickers = require("telescope.pickers")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values

	local function python_modules_finder(opts, ctx)
		local output = get_packages()
		local items = {}
		for _, package_name in ipairs(output) do
			table.insert(items, {
				value = package_name,
				display = package_name,
				ordinal = package_name,
			})
		end
		return items
	end

	-- Create custom previewer
	local package_previewer = previewers.new_buffer_previewer({
		title = "Package Documentation",
		get_buffer_by_name = function(_, entry)
			return entry.value
		end,
		define_preview = function(self, entry)
			local docs = M.get_documentation(entry.value)
			vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, docs)
			vim.api.nvim_set_option_value("filetype", "pydoc", { buf = self.state.bufnr })
		end,
	})

	local function on_package_select(prompt_bufnr)
		local selection = action_state.get_selected_entry()
		if selection then
			M.show_documentation(selection.value)
		end
	end

	local opts = {
		finder = finders.new_table({
			results = python_modules_finder(),
			entry_maker = function(entry)
				return {
					display = entry.display,
					value = entry.value,
					ordinal = entry.ordinal,
				}
			end,
		}),
		sorter = conf.generic_sorter(),
		previewer = package_previewer,
		attach_mappings = function(_, map)
			map("i", "<CR>", function(prompt_bufnr)
				on_package_select(prompt_bufnr)
			end)
			map("n", "<CR>", function(prompt_bufnr)
				on_package_select(prompt_bufnr)
			end)
			return true
		end,
	}

	if M.config and M.config.picker and M.config.picker.telescope_options then
		opts = vim.tbl_extend("force", opts, M.config.picker.telescope_options)
	end

	pickers.new(opts, {}):find()
end

-- Show Snacks picker
function M.show_snacks_picker()
	local snacks = require("snacks")

	local function python_modules_finder(opts, ctx)
		local output = get_packages()
		local items = {}
		for _, package_name in ipairs(output) do
			table.insert(items, {
				text = package_name, -- The package name as the main text in the picker
				package_name = package_name, -- Store the package name for the action
			})
		end
		return items
	end

	local function on_package_select(package_name)
		M.show_documentation(package_name)
	end

	local opts = {
		finder = python_modules_finder,
		format = "text",
		title = "Python Modules",
		preview = function(ctx)
			if ctx.item then
				local package_name = ctx.item.package_name
				ctx.preview:set_lines(M.get_documentation(package_name))
				ctx.preview:highlight({ ft = "pydoc" })
			else
				ctx.preview:reset()
			end
		end,
		actions = {
			confirm = function(picker, item)
				if item then
					snacks.picker.actions.close(picker) -- Close the picker
					on_package_select(item.package_name) -- Call your custom action
				end
			end,
		},
	}

	if M.config and M.config.picker and M.config.picker.snacks_options then
		opts = vim.tbl_extend("force", opts, M.config.picker.snacks_options)
	end

	snacks.picker.pick(opts)
end

-- Package docs cache
local package_docs = {}

-- Get the documentation
function M.get_documentation(module_name)
	if package_docs[module_name] == nil then
		local docs = vim.fn.systemlist("python -m pydoc " .. module_name)
		if vim.v.shell_error ~= 0 then
			return { "No documentation available for " .. module_name }
		end

		package_docs[module_name] = docs
	end

	return package_docs[module_name]
end

-- Show documentation in new buffer
function M.show_documentation(package_name)
	local doc = M.get_documentation(package_name)

	-- Create new buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, doc)

	-- Set buffer options
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "pydoc", { buf = buf })

	-- Open window based on config
	if M.config.window.type == "split" then
		vim.cmd("split")
	elseif M.config.window.type == "vsplit" then
		vim.cmd("vsplit")
	else -- floating
		-- TODO: Implement floating window?
	end

	vim.api.nvim_set_current_buf(buf)

	-- Set up keymaps for the documentation window
	local opts = { noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "q", ":close<CR>", opts)
	vim.keymap.set("n", "<Esc>", ":close<CR>", opts)
end

return M
