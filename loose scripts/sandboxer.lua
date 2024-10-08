--[[Sandboxer
a Script made by Superpowers04 that isolates errors and prevents most of them from halting your avatar while providing basic highlighting and stuff
 It works by making a fake events table and applying pcalls to them
Just require the script to use the events setup
For isolating specific calls you can use guardFunction and runFunction

For example:
```lua
local sandboxer = require('SANDBOXER')


local guardedFunction = sandboxer.guardFunction(function()
	doThingHere()
end)
guardedFunction()

sandboxer.runFunction(print,"a String")```

]]


-- TODO - ADD FIX SUGGESTIONS

local EventAPI = events
local eventList = events:getEvents()
local sandboxer = {
	underAPI = events,
	errorForClients = false,
	colors = {
		stackTrace="#FFAAAA",
		path="#aa77aa",
		line="#aa0077",
		lineNumber="#777799",
		error="#FF2233",
		info="#AA9999",
		seperator="#FF0011",
	},
	limit = 0,
	errorFunction = function() end
}
local errorCount = 0
local lastCheck = 0
local HASERRORED = false
events.TICK:register(function()
	if(errorCount > (host:isHost() and sandboxer.limit or math.min(sandboxer.limit,20))) then
		if(HASERRORED) then
			error('SANDBOXER HAD AN ERROR PAST ERROR LIMIT')
		end
		printJson(toJson({text="-- ERROR LIMIT REACHED WITHIN 40 TICKS, EVENTS CLEARED --\n",color="#FF2233"}))
		-- error('Too many errors within 40 ticks, stopping!')
		lastCheck = 0
		errorCount = 0
		for i,v in pairs(eventList) do
			events[i]:clear()
		end
		if(not HASERRORED and sandboxer.errorFunction) then
			sandboxer.errorFunction()
		end
		HASERRORED = true
	end
	lastCheck = lastCheck + 1
	if(lastCheck > 40) then
		lastCheck = 0
		errorCount = 0
	end
end,'sandboxer.errorwatch')
local insert = table.insert
local concat = table.concat
local char = string.char
local _NL = "\n"
local _C = ":"
local s = " "
local ss = "  "
local function decodeScript(path)
	local bytes = avatar:getNBT().scripts[path]
	if not bytes then return end
	local script = {}
	local abs = abs
	for _,v in pairs(bytes) do
		script[#script+1] = char(v % 256)
	end
	return concat(script,'')
end
local function findLine(str,index)
	local lineCount=tonumber(index)
	-- local line = "UNABLE TO FIND LINE?"
	local count = 1
	for curLine in str:gmatch('([^\n]+)') do
		-- print(count,lineCount)
		if(count == lineCount) then
			return curLine
		end
		count = count+1
	end
	return nil
end
local cache = {}

function sandboxer.parseStack(tab,a,b,c)
	a = a:gsub('/','.'):gsub('[^a-zA-Z0-9%.]','')
	local ret = {}

	local contents = cache[a] or decodeScript(a)
	local colors = sandboxer.colors
	if(contents and b) then
		cache[a] = contents
		local line = findLine(contents,b) or "UNABLE TO FIND LINE?"
		ret[#ret+1] = ({text = tab..a,color=colors.path,hoverEvent={
			action="show_text",
			contents={
				{text = a,color=colors.path},
				{text = _C..b..": ",color=colors.lineNumber},
				{text = line,color=colors.line},
			}
		}})
	else
		ret[#ret+1] = ({text = tab..a,color=colors.path})
	end
	ret[#ret+1] = ({text = ':'..b,color=colors.lineNumber})
	if(c:sub(1,4) == " in ") then
		ret[#ret+1] = ({text = ':'..c.._NL,color=colors.info})
	else
		ret[#ret+1] = ({text = _C..c.._NL,color=colors.error})
	end
	return ret
end

function sandboxer.printErr(err)
	if(not host:isHost() and sandboxer.errorForClients) then
		error(err)
	end
	local pr = {}
	local colors = sandboxer.colors
	if(err) then
		local nbtList = avatar:getNBT().scripts
		insert(pr,{text = "ERROR CAUGHT FOR " .. avatar:getName() .. "(" .. (user:isLoaded() and user:getName() or "ENTITY NOT LOADED") .. ")----\n",color=colors.seperator})
		err:gsub("^([^\n]-):([^\n]-)( [^\n]+)",function(...)
			local tbl = sandboxer.parseStack(s,...)
			for _,v in ipairs(tbl) do
				pr[#pr+1]=v 
			end
			return ""
		end)
		:gsub("stack traceback:",function(a,b,c)
			insert(pr,{text = s.."Stack trace: ----\n",color=colors.stackTrace})
			return ""
		end)
		:gsub("([^\n]-):([^\n]-):?( [^\n]+)",function(...)
			local tbl = sandboxer.parseStack(ss,...)
			if(not tbl[1]) then return "" end
			for _,v in ipairs(tbl) do
				pr[#pr+1]=v 
			end
			return ""
		end)
		insert(pr,{text = "----\n",color=colors.seperator})
	else
		pr= {text="Error thrown without any object!\n",color=colors.error}
	end
	cache = {}
	printJson(toJson(pr))
end
function sandboxer.guardFunction(func)
	return function(...)
		local succ,err,a,b,c,d = pcall(func,...)
		if succ then 
			return err,a,b,c,d
		end
		errorCount = errorCount + 1
		local succ,printerr = pcall(sandboxer.printErr,err)
		if(succ) then return end
		printJson(toJson({text=tostring(err),color="red"}))
		printJson(toJson({text=tostring(printerr),color="#ff0099"}))
	end
end
function sandboxer.runFunction(func,...)
	local succ,err,a,b,c,d = pcall(func,...)
	if succ then 
		return err,a,b,c,d
	end
	errorCount = errorCount + 1
	local succ,printerr = pcall(sandboxer.printErr,err)
	if(succ) then return end
	printJson(toJson({text=tostring(err),color="red"}))
	printJson(toJson({text=tostring(printerr),color="#ff0099"}))

end
local fakeEvent = {
	register = function(self,func,...)
		self.event:register(sandboxer.guardFunction(func),...)
	end,
	remove = function(self,...)
		self.event:remove(...)
	end,
	clear = function(self,...)
		self.event:clear(...)
	end,
	getRegisteredCount = function(self,...)
		self.event:getRegisteredCount(...)
	end,
}
fakeEvent.new = function(name,event)
	return setmetatable({id=name,event=event,
		register = fakeEvent.register,
		remove = fakeEvent.remove,
		clear = fakeEvent.clear,
		getRegisteredCount = fakeEvent.getRegisteredCount,
	},{__index=event,__newindex=event})
end
local eventStuff = {getEvents=function() return eventList end}
for i,v in pairs(eventList) do
	eventStuff[i:lower()] = fakeEvent.new(i,v)
end

_G.events = setmetatable({},{
	__index=function(this,key)
		return rawget(eventStuff,key:lower())
	end,
	__newindex=function(this,key,value)
		key = key:lower()
		set = rawget(eventStuff,key)
		if(set == nil) then error('No such event "'..key..'"') end
		set:register(value,tostring(value))
	end}
)

return sandboxer
