local veil = require("veil")
local utils = require("veil.utils")

local Rendered = {
	text = {},
	nlines = 0,
	longest = 0,
	virt = true,
	hl = "Normal",
}

function Rendered:pad(width)
	local text = vim.deepcopy(self.text)
	local padding = 0
	if self.longest < width and self.longest > 0 then
		padding = math.ceil((width - self.longest) / 2)
	end
	for lno, line in ipairs(text) do
		text[lno] = string.rep(" ", padding) .. line
	end
	return setmetatable({
		text = text,
	}, {
		__index = self,
	})
end

function Rendered:new(opts)
	local new = vim.tbl_deep_extend("keep", opts or {}, self)
	return new
end

---@alias Highlight { fg: string|nil, bg: string|nil }
---@class Section
---@field interactive boolean Whether or not the section is interactive.
---@field hl string | Highlight | fun(self: Section):Highlight Highlight group to use for the section.
---@field contents string[]|string|fun(self:Section):string[] The line or lines to be displayed
local Section = {
	---@type table<string, any>
	state = {},
	interactive = false,
	hl = "Normal",
}

---@type fun(self: Section) Called when <CR> is entered with the cursor over a line in this section

function Section:on_interact() end

---@type fun(self: Section) Called once, when the component is initialized
function Section:init() end

---@type fun(self: Section):string[]
function Section:contents()
	return { "configure your veil!" }
end

---@alias SectionOpts Section
---@type fun(opts: table):Section
function Section:new(opts)
	local new = vim.tbl_deep_extend("keep", opts or {}, self)

	local mt = {
		__index = new.state,
		__newindex = function(state, k, v)
			-- Reserved names
			if k == "interactive" or k == "contents" then
				error("Section." .. k .. " cannot be updated after initialization", 2)
			else
				rawset(state, k, v)
			end
		end,
	}

	if type(new.hl) == "string" then
		new.hl = vim.api.nvim_get_hl_by_name(new.hl, true)
	end

	-- Generate random id for section hlgroup
	local hl_id = "VeilSection" .. math.floor(math.random() * 100)

	-- Build the section and render function
	mt.__index.contents = new.contents
	mt.__index.interactive = new.interactive
	mt.__index.hl = hl_id
	mt.__index.hl_val = new.hl
	---@type fun(tbl:Section):Rendered
	mt.__index.render = function(tbl)
		-- Create the new hlgroup
		local hl_val
		if type(tbl.hl_val) == "function" then
			hl_val = tbl:hl_val()
		else
			hl_val = tbl.hl_val
		end
		veil.ns = vim.api.nvim_create_namespace("veil")
		vim.api.nvim_set_hl(veil.ns, tbl.hl, hl_val)
		local contents = nil
		if type(tbl.contents) == "function" then
			contents = tbl:contents()
		elseif type(tbl.contents) == "table" then
			contents = tbl.contents
		elseif type(tbl.contents) == "string" then
			contents = { tbl.contents }
		else
			error("Section.contents must be a function, string[], or string", 2)
		end
		return Rendered:new({
			text = contents,
			nlines = #contents,
			longest = utils.longest_line(contents),
			virt = not tbl.interactive,
			hl = tbl.hl,
			interaction = tbl.interactions,
		})
	end

	return setmetatable({}, mt)
end

return Section
