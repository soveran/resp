local resp = require("resp")

local client = resp.new("localhost", 6379)

local assert_equal = function(a, b)
	assert(a == b, tostring(a) .. " ~= " .. tostring(b))
end

assert_equal(client:call("SELECT", "3"), "OK")
assert_equal(client:call("FLUSHDB"), "OK")

assert_equal(client:call("PING"), "PONG")
assert_equal(client:call("ECHO", "bar"), "bar")
assert_equal(client:call("ECHO", "foo\r\nbar"), "foo\r\nbar")
assert_equal(client:call("SET", "foo", "hello world"), "OK")
assert_equal(client:call("GET", "foo"), "hello world")
assert_equal(client:call("GET", "bar"), nil)
assert_equal(client:call("SET", "bar", "\r\n"), "OK")
assert_equal(client:call("GET", "bar"), "\r\n")

result = client:call("SMEMBERS", "baz")

assert_equal(type(result), "table")
assert_equal(#result, 0)

assert_equal(client:call("MULTI"), "OK")
assert_equal(client:call("PING"), "QUEUED")
assert_equal(client:call("ECHO", "bar"), "QUEUED")

local result = client:call("EXEC")

assert_equal(result[1], "PONG")
assert_equal(result[2], "bar")

client:quit()
