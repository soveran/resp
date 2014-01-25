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

Installation
------------

You need to have [lsocket](http://www.tset.de/lsocket/) installed,
then just copy resp.lua anywhere in your package.path.
