RESP
====

Lightweight RESP client

Description
-----------


Lightweight [RESP](http://redis.io/topics/protocol) client that
can be used for interacting with Redis servers.

Usage
-----

```lua
local resp = require("resp")
local client = resp.new("localhost", 6379)

assert("OK" == client:call("SET", "foo", "42"))
assert("42" == client:call("GET", "foo"))
```

Pipelining
----------

You can pipeline commands by using the `queue`/`commit` methods.

```lua
local resp = require("resp")
local client = resp.new("localhost", 6379)

client:queue("ECHO", "foo")
client:queue("ECHO", "bar")

assert_equal(#client.buff, 2)

result = client:commit()

assert_equal(#client.buff, 0)

assert_equal(result[1], "foo")
assert_equal(result[2], "bar")
```

MONITOR and SUBSCRIBE
---------------------

For commands like `MONITOR` and `SUBSCRIBE`, you can keep reading
messages from the server:

```lua
local resp = require("resp")
local c1 = resp.new("localhost", 6379)
local c2 = resp.new("localhost", 6379)

-- Subscribe to channel "foo"
c1:call("SUBSCRIBE", "foo")

-- Publish to channel "foo"
c2:call("PUBLISH", "foo", "hello")
c2:call("PUBLISH", "foo", "world")

r1 = c1:read()
r2 = c1:read()

-- Messages have type, channel and content
assert_equal(r1[1], "message")
assert_equal(r1[2], "foo")
assert_equal(r1[3], "hello")

assert_equal(r2[1], "message")
assert_equal(r2[2], "foo")
assert_equal(r2[3], "world")
```

Encoding
--------

Aside from creating a client, resp.lua can also be used to
encode any message with the RESP protocol:

```lua
local resp = require("resp")

assert_equal("*1\r\n$3\r\nFOO\r\n\r\n", resp.encode("FOO"))
```

Installation
------------

You need to have [lsocket](http://www.tset.de/lsocket/) installed,
then just copy resp.lua anywhere in your package.path.
