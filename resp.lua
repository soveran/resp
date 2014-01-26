local lsocket = require("lsocket")

-- Establish the connection
local connect = function(self, host, port)
	local sock = assert(lsocket.connect(host, port))

	lsocket.select(nil, {sock})

	assert(sock:status())

	self.sock = sock
end

-- Transform arguments to RESP
local encode = function(...)
	local res = {}

	table.insert(res, ("*" .. select("#", ...)))

	for i, v in ipairs{...} do
		table.insert(res, "$" .. #v)
		table.insert(res, v)
	end

	table.insert(res, "\r\n")

	return table.concat(res, "\r\n")
end

local discard_eol = function(sock)
	assert(sock:recv(2))
end

-- Read until "\r\n"
local readstr = function(sock)
	local res = {}
	local ch = sock:recv(1)

	while (ch) do
		if (ch == "\r") then

			-- Discard "\n"
			assert(sock:recv(1))

			return table.concat(res)
		end

		table.insert(res, ch)
		ch = sock:recv(1)
	end
end

-- Read line as a number
local readnum = function(sock)
	return tonumber(readstr(sock))
end

local codex

codex = {

	-- RESP status
	["+"] = readstr,

	-- RESP error
	["-"] = readstr,

	-- RESP integer
	[":"] = readnum,

	-- RESP string
	["$"] = function(sock)
		local size = readnum(sock)

		if (size == -1) then
			return nil
		elseif (size == 0) then
			discard_eol(sock)
			return ""
		end

		assert(size > 0)

		local res = sock:recv(size)

		discard_eol(sock)

		return res
	end,

	-- RESP array
	["*"] = function(sock)
		local res = {}
		local curr = 1
		local size = readnum(sock)

		if (size == -1) then
			return nil
		elseif (size == 0) then
			return res
		end

		while (curr <= size) do
			local prefix = sock:recv(1)

			table.insert(res, codex[prefix](sock))

			curr = curr + 1
		end

		return res
	end,
}

-- Send commands to Redis
local write = function(sock, ...)
	lsocket.select(nil, {sock})

	return assert(sock:send(encode(...)))
end

-- Read reply from Redis
local read = function(sock)
	lsocket.select({sock})

	local prefix = assert(sock:recv(1))

	return codex[prefix](sock)
end

-- Call Redis command and return the reply
local call = function(self, ...)
	assert(write(self.sock, ...))

	return read(self.sock)
end

-- Close the connection
local quit = function(self)
	if self.sock then
		call(self, "QUIT")

		self.sock:close()
		self.sock = nil
	end
end

local methods = {
	quit = quit,
	call = call,
}

local new = function(host, port)
	local self = setmetatable({}, {__index = methods})

	connect(self, host, port)

	return self
end

return {
	new = new,
}
