local lsocket = require("lsocket")

-- Establish the connection
local connect = function(self, host, port)
	sock = assert(lsocket.connect(host, port))

	lsocket.select(nil, {sock})

	assert(sock:status())

	self.sock = sock
end

-- Transform arguments to RESP
local encode = function(...)
	result = {}

	table.insert(result, ("*" .. select("#", ...)))

	for i, v in ipairs{...} do
		table.insert(result, "$" .. #v)
		table.insert(result, v)
	end

	table.insert(result, "\r\n")

	return table.concat(result, "\r\n")
end

-- Read until "\r\n"
local readline = function(sock)
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

local codex

codex = {

	-- RESP status
	["+"] = function(sock)
		return readline(sock)
	end,

	-- RESP error
	["-"] = function(sock)
		return readline(sock)
	end,

	-- RESP integer
	[":"] = function(sock)
		return tonumber(readline(sock))
	end,

	-- RESP string
	["$"] = function(sock)
		local res = sock:recv(tonumber(readline(sock)))

		sock:recv(2)

		return res
	end,

	-- RESP array
	["*"] = function(sock)
		local res = {}
		local curr = 1
		local size = tonumber(readline(sock))

		if (size == -1) then
			return nil
		elseif (size == 0) then
			return
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
	lsocket.select(nil, {socket})

	return assert(sock:send(encode(...)))
end

-- Read reply from Redis
local read = function(socket)
	lsocket.select({socket})

	local prefix = assert(socket:recv(1))

	return codex[prefix](socket) or nil
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
	self = setmetatable({}, {__index = methods})

	connect(self, host, port)

	return self
end

return {
	new = new,
}
