**(see typestable0.6 branch)**

# Redis.jl


[![Build Status](https://travis-ci.org/merl-dev/Redis.jl.svg?branch=hiredis)](https://travis-ci.org/merl-dev/Redis.jl) [![Coverage Status](https://coveralls.io/repos/github/merl-dev/Redis.jl/badge.svg?branch=master)](https://coveralls.io/github/merl-dev/Redis.jl?branch=hiredis) [![DataFrames](http://pkg.julialang.org/badges/Redis_0.5.svg)](http://pkg.julialang.org/?pkg=Redis&ver=0.5)



Redis.jl is a fully-featured Redis client for the Julia programming language. The implementation is an attempt at an easy to understand, minimalistic API that mirrors actual Redis commands as closely as possible.

## libhiredis

Merges a debugged version of HiRedis.jl, based on the C-language hiredis interface to Redis. Thus far all basic commands pass tests without modification to the original Redis.jl API. Performance enhancements are significant, see BenchmarkNotes.md for examples. **Redis responses
are no longer converted to complex types.  

In order to maximize performance, send string commands using `do_command`:  for example, instead of `set(conn, "akey", "avalue")`,
use `do_command(conn, "set akey avalue")` in order to bypass command parsing.  In addition, for use cases where Redis server responses are not required immediately, use pipeline commands: `pipeline_command(conn, "set akey value")`. 


_TODO_:
* key-prefixing
* Sentinels tests
* Implement the libhiredis `RedisAsyncContext` and `redisAsyncCommand` interfaces
* Clusters remain without commands nor tests
* create a clean benchmark suite

## Basics

The Redis.jl API resides in the `Redis` module.

```
using Redis
```

The main entrypoint into the API is the `RedisConnection`, which represents a stateful TCP connection to a single Redis server instance. A single constructor allows the user to set all parameters while supplying the usual Redis defaults. Once a `RedisConnection` has been created, it can be used to access any of the expected Redis commands.

```
conn = RedisConnection() # host=127.0.0.1, port=6379, db=0, no password
# conn = RedisConnection(host="192.168.0.1", port=6380, db=15, password="supersecure")

set(conn, "foo", "bar")
get(conn, "foo") # Returns "bar"
```

For any Redis command `x`, the Julia function to call that command is `x`. Redis commands with spaces in them have their spaces replaced with underscores (`_`). For those already familiar with available Redis commands, this convention should make the API relatively straightforward to understand. There are two exceptions to this convention due to conflicts with Julia:

* The _type_ key command is `keytype`
* The _eval_ scripting command is `evalscript`

When the user is finished interacting with Redis, the connection should be destroyed to prevent resource leaks:

```
disconnect(conn)
```

The `disconnect` function can be used with any of the connection types detailed below.

### Commands with options

Some Redis commands have a more complex syntax that allows for options to be passed to the command. Redis.jl supports these options through the use of a final varargs parameter to those functions (for example, `scan`). In these cases, the options should be passed as individual strings at the end of the function.

```
scan(conn, 0, "match", "foo*")
```

If users are interested, the API could be improved to provide custom functions for these complex commands.

## Pipelining

Redis.jl supports pipelining through the `PipelineConnection`. Commands are executed in much the same way as standard Redis commands:

```
pipeline = open_pipeline(conn)
set(pipeline, "somekey", "somevalue")
```

Commands will be sent directly to the Redis server without waiting for a response. Responses can be read at any time in the future using the `read_pipeline` command:

```
responses = read_pipeline(pipeline) # responses == ["OK"]
```

*Important:* The current `PipelineConnection` implementation is *not* threadsafe. If multiple threads require access to Redis pipelines, a separate `PipelineConnection` should be created for each thread. This limitation could be addressed in a future commit if there is a need.

## Transactions

Redis.jl supports MULTI/EXEC transactions through two methods: using a `RedisConnection` directly or using a specialized `TransactionConnection` derived from a parent connection.

### Transactions using the RedisConnection

If the user wants to build a transaction a single time and execute it on the server, the simplest way to do so is to send the commands as you would at the Redis cli.

```
multi(conn)
set(conn, "foo", "bar")
get(conn, "foo") # Returns "QUEUED"
exec(conn) # Returns ["OK", "bar"]
get(conn, "foo") # Returns "bar"
```

It is important to note that after the final call to `exec`, the RedisConnection is returned to a 'normal' state.

### Transactions using the TransactionConnection

If the user is planning on using multiple transactions on the same connection, it may make sense for the user to keep a separate connection for transactional use. The `TransactionConnection` is almost identical to the `RedisConnection`, except that it is always in a `MULTI` block. The user should never manually call `multi` with a `TransactionConnection`.

```
trans = open_transaction(conn)
set(trans, "foo", "bar")
get(trans, "foo") # Returns "QUEUED"
exec(trans) # Returns ["OK", "bar"]
get(trans, "foo") # Returns "QUEUED"
multi(trans) # Throws a ServerException
```

Notice the subtle difference from the previous example; after calling `exec`, the `TransactionConnection` is placed into another `MULTI` block rather than returning to a 'normal' state as the `RedisConnection` does.

## Pub/Sub (NEEDS REWRITE)

Redis.jl provides full support for Redis pub/sub. Publishing is accomplished by using the command as normal:

```
publish(conn, "channel", "hello, world!")
```

Subscriptions are handled using the `SubscriptionConnection`. Similar to the `TransactionConnection`, the `SubscriptionConnection` is constructed from an existing `RedisConnection`. Once created, the `SubscriptionConnection` maintains a simple event loop that will call the user's defined function whenever a message is received on the specified channel.

```
x = Any[]
f(y) = push!(x, y)
sub = open_subscription(conn)
subscribe(sub, "baz", f)
publish(conn, "baz", "foobar")
x # Returns ["foobar"]
```

Multiple channels can be subscribed together by providing a `Dict{String, Function}`.

```
x = Any[]
f(y) = push!(x, y)
sub = open_subscription(conn)
d = Dict{String, Function}({"baz" => f, "bar" => println})
subscribe(sub, d)
publish(conn, "baz", "foobar")
x # Returns ["foobar"]
publish(conn, "bar", "anything") # "anything" written to stdout
```

Pattern subscription works in the same way through use of the `psubscribe` function. Channels can be unsubscribed through `unsubscribe` and `punsubscribe`.

Note that the async event loop currently runs until the `SubscriptionConnection` is disconnected, regardless of how many subscriptions the client has active. Event loop error handling should be improved in an update to the API.

### Subscription error handling

When a `SubscriptionConnection` instance is created via `open_subscription`, it spawns a routine that runs in the background to process events received from the server. In the case that Redis.jl encounters an error within this loop, the default behavior is to disregard the error and continue on. If the user would like finer control over this error handling, `open_subscription` accepts an optional `Function` parameter as its final argument. If this is provided, Redis.jl will call the provided function passing it the caught `Exception` as its only parameter.

## Sentinel

Redis.jl also provides functionality for interacting with Redis Sentinel instances through the `SentinelConnection`. All Sentinel functionality other than `ping` is implemented through the `sentinel_` functions:

```
sentinel = SentinelConnection() # Constructor has the same options as RedisConnection
sentinel_masters(sentinel) # Returns an Array{Dict{String, String}} of master info
```

`SentinelConnection` is also `SubscribableConnection`, allowing the user to build a `SubscriptionConnection` for monitoring cluster health through Sentinel messages. See [the Redis Sentinel documentation](http://redis.io/topics/sentinel) for more information.

## Streaming Scanners

In order to simplify use of the Redis scan commands, SCAN (keys), SSCAN (sets), ZSCAN (ordered sets), and HSCAN (hashes), a streaming interface is provided. To initialize a scan use the appropriate constructor:

`KeyScanner(conn::RedisConnection, match::AbstractString, count::Int)`

`SetScanner(conn::RedisConnection, key::AbstractString, match::AbstractString, count::Int)`

`OrderedSetScanner(conn::RedisConnection, key::AbstractString, match::AbstractString, count::Int)`

`HashScanner(conn::RedisConnection, key::AbstractString, match::AbstractString, count::Int)`

`match` is used for pattern matching, and defaults to "\*",  while `count` specifies the number of items returned per iteration and defaults to 1.

Three methods are provided for scanning:

`next!(ss::StreamScanner, count)` retrieves `count` elements as an `Array` or `Dict`.  `count` defaults to the value
used in the constructor, but can be modified per request. __As per the Redis spec, each call to `next!` may return one or
more elements that were retrieved in a previous call.__

`collect(ss::StreamScanner)` will keep scanning until all the elements have bee retrieved.

`collectAsync!(ss::StreamScanner, coll::<Collection Type>; cb::Function==nullcb)` enables asynchronous execution of a scan
accumulating results in a predefined collection object, with an optional callback parameter that defaults to do nothing.  The callback function should take one parameter, the result collection and do something appropriate for that collection type.

Note the following caveats from the Redis documentation at http://redis.io/commands/scan:

    * The SCAN family of commands only offer limited guarantees about the returned elements since the collection
    that we incrementally iterate can change during the iteration process.

    * Basically with COUNT the user specified _the amount of work that should be done at every call in order to
      retrieve elements from the collection_. This is __just a hint__ for the implementation, however generally
      speaking this is what you could expect most of the times from the implementation.

__Please refer to the Redis documentation for more details.__


### Notes

Actual API usage can be found in test/redis_tests.jl.

### Redis Commands returning 'NIL'

The following methods return a `Nullable{T}(value)` corresponding to a Redis 'NIL'.

#### Strings
* `get(conn, "non_existent_key")`
* `mget(conn, "non_existent_key1", "non_existent_key2", "non_existent_key3")`

#### Lists
* `lindex(conn, "non_existent_list", 1)`
* `lindex(conn, "one_element_list", 2)`
* `lpop(conn, "non_existent_list")`
* `rpop(conn, "non_existent_list")`
* `rpoplpush(conn, "non_existent_list", "some_list")`

#### Sets
* `spop(conn, "empty_set")`
* `srandmember(conn, "empty_set")`     

####Sorted Sets
* `zrank(conn, "ordered_set", "non_existent_member")`
* `zrevrank(conn, "ordered_set", "non_existent_member")`
* `zscore(conn, "ordered_set", "non_existent_member")`

#### Hashes
* `hget(conn, "some_hash", "non_existent_field")`
* `hmget(conn, "some_hash", "nofield1", "nofield2")`
