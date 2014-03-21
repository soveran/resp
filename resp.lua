local lsocket = require("lsocket")

local lsocket_select = lsocket.select
local lsocket_connect = lsocket.connect

local insert = table.insert
local concat = table.concat

-- Establish the connection
local connect = function(self, host, port)
	local sock = assert(lsocket_connect(host, port))

	lsocket_select(nil, {sock})

	assert(sock:status())

	self.sock = sock
end

-- Transform arguments to RESP
local encode = function(...)
	local res = {}

	insert(res, ("*" .. select("#", ...)))

	for i, v in ipairs{...} do
		insert(res, "$" .. #v)
		insert(res, v)
	end

	insert(res, "\r\n")

	return concat(res, "\r\n")
end

-- Low level read from socket
local recv = function(sock, size)
	lsocket_select({sock})
	return assert(sock:recv(size))
end

-- Low level write to socket
local send = function(sock, str)
	lsocket_select(nil, {sock})
	return assert(sock:send(str))
end

-- Read size bytes from socket
local read = function(sock, size)
	local res = ""
	local str

	-- NOTE: it might seem logical to use a table to collect
	-- the values and concat at the end, but in reality the
	-- case where what we read is what we get happens majority
	-- of the time, so the loop doesn't execute in that scenario
	-- at all, and therefore we avoid a string concat when we
	-- encounter the common case.
	repeat
		str = recv(sock, size - #res)
		res = res .. str
	until #res == size

	return res
end

-- Write str to socket
local write = function(sock, str)
	local size = send(sock, str)

	while size < #str do
		size = size + send(sock, str:sub(size))
	end
end

local discard_eol = function(sock)
	read(sock, 2)
end

-- Read until "\r\n"
local readstr = function(sock)
	local res = {}
	local ch = read(sock, 1)

	while ch do
		if (ch == "\r") then

			-- Discard "\n"
			read(sock, 1)

			return concat(res)
		end

		insert(res, ch)

		ch = read(sock, 1)
	end
end

-- Read line as a number
local readnum = function(sock)
	return tonumber(readstr(sock))
end

-- Forward declaration
local codex

-- Send commands to Redis
local write_command = function(sock, ...)
	write(sock, encode(...))
end

-- Read reply from Redis
local read_reply = function(sock)
	local prefix = read(sock, 1)

	return codex[prefix](sock)
end

-- RESP parser
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

		local res = read(sock, size)

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
			insert(res, read_reply(sock))
			curr = curr + 1
		end

		return res
	end,
}

-- Call Redis command and return the reply
local call = function(self, ...)
	write_command(self.sock, ...)

	return read_reply(self.sock)
end

-- Close the connection
local quit = function(self)
	if self.sock then
		call(self, "QUIT")

		self.sock:close()
		self.sock = nil
	end
end

-- Buffer commands
local queue = function(self, ...)
	insert(self.buff, {...})
end

-- Send commands to Redis
local commit = function(self)
	local res = {}

	for _, v in ipairs(self.buff) do
		write_command(self.sock, unpack(v))
	end

	for _, _ in ipairs(self.buff) do
		insert(res, read_reply(self.sock))
	end

	self.buff = {}

	return res
end

local methods = {
	quit = quit,
	call = call,
	queue = queue,
	commit = commit,
}

local new = function(host, port)
	local self = setmetatable({}, {__index = methods})

	self.buff = {}

	connect(self, host, port)

	return self
end

return {
	new = new,
}
