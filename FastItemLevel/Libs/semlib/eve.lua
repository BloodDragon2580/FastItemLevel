local F, Events, A, T = CreateFrame('frame'), {}, ...

local function Raise(_, event, ...)
	if Events[event] then
		for module in pairs(Events[event]) do
			module[event](module, ...)
		end
	end
end

local function RegisterEvent(module, event, func)
	if func then
		rawset(module, event, func)
	end
	if not Events[event] then
		Events[event] = {}
	end
	Events[event][module] = true
	if strmatch(event, '^[%u_]+$') then
		pcall(function() return F:RegisterEvent(event) end)
	end
	return module
end

local function UnregisterEvent(module, event)
	if Events[event] then
		Events[event][module] = nil
		if not next(Events[event]) and strmatch(event, '^[%u_]+$') then
			F:UnregisterEvent(event)
		end
	end
	return module
end

local Module = {
	__newindex = RegisterEvent,
	__call = Raise,
	__index = {
		RegisterEvent = RegisterEvent,
		UnregisterEvent = UnregisterEvent,
		Raise = Raise,
	},
}

T.Eve = setmetatable({}, {
	__call = function(eve)
		local module = setmetatable({}, Module)
		eve[ #eve + 1 ] = module
		return module
	end,
})

F:SetScript('OnEvent', Raise)
