require("pl.strict")

local resp = require("resp")

local client = resp.new("localhost", 6379)

local assert_equal = function(a, b)
	assert(a == b, tostring(a) .. " ~= " .. tostring(b))
	io.write(".")
end

-- RESP status
assert_equal(client:call("SELECT", "3"), "OK")
assert_equal(client:call("FLUSHDB"), "OK")
assert_equal(client:call("PING"), "PONG")

-- RESP error
assert_equal(client:call("PANG"), "ERR unknown command 'PANG'")

-- RESP integer
assert_equal(client:call("DBSIZE"), 0)

-- RESP string
assert_equal(client:call("ECHO", "bar"), "bar")
assert_equal(client:call("ECHO", ""), "")
assert_equal(client:call("ECHO", "\r\n"), "\r\n")

-- RESP array
assert_equal(client:call("MULTI"), "OK")
assert_equal(client:call("PING"), "QUEUED")
assert_equal(client:call("DBSIZE"), "QUEUED")
assert_equal(client:call("SMEMBERS", "bar"), "QUEUED")
assert_equal(client:call("BRPOP", "bar", "1"), "QUEUED")

local result = client:call("EXEC")

-- (status)
assert_equal(result[1], "PONG")

-- (integer)
assert_equal(result[2], 0)

-- (empty)
assert_equal(type(result[3]), "table")
assert_equal(#result[3], 0)

-- (nil)
assert_equal(result[4], nil)

-- pipelining

assert_equal(#client.buff, 0)

client:queue("ECHO", "foo")
client:queue("ECHO", "bar")

assert_equal(#client.buff, 2)

result = client:commit()

assert_equal(#client.buff, 0)

assert_equal(result[1], "foo")
assert_equal(result[2], "bar")

local c1 = resp.new("localhost", 6379)
local c2 = resp.new("localhost", 6379)

c1:queue("ECHO", "c1-foo")
c1:queue("ECHO", "c1-bar")

assert_equal(#c1.buff, 2)
assert_equal(#c2.buff, 0)

c2:queue("ECHO", "c2-foo")
c2:queue("ECHO", "c2-bar")

assert_equal(#c1.buff, 2)
assert_equal(#c2.buff, 2)

r1 = c1:commit()
r2 = c2:commit()

assert_equal(#c1.buff, 0)
assert_equal(#c2.buff, 0)

assert_equal(r1[1], "c1-foo")
assert_equal(r1[2], "c1-bar")

assert_equal(r2[1], "c2-foo")
assert_equal(r2[2], "c2-bar")

client:quit()

io.write("\r\n")
