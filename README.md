# Redis.jl


[![Build Status](https://travis-ci.org/merl-dev/Redis.jl.svg?branch=hiredis)](https://travis-ci.org/merl-dev/Redis.jl) [![Coverage Status](https://coveralls.io/repos/github/merl-dev/Redis.jl/badge.svg?branch=master)](https://coveralls.io/github/merl-dev/Redis.jl?branch=hiredis) [![DataFrames](http://pkg.julialang.org/badges/Redis_0.5.svg)](http://pkg.julialang.org/?pkg=Redis&ver=0.5)



Redis.jl is a fully-featured Redis client for the Julia programming language. The implementation is an attempt at an easy to understand, minimalistic API that mirrors actual Redis commands as closely as possible.

## WIP: Type Stable HiRedis branch
Merges a debugged version of HiRedis.jl, based on the C-language hiredis interface to Redis.
* faster command parser
* new parsers:
    * `parse_string_reply` => Redis Simple Strings
    * `parse_int_reply` => Redis Integers
    * `parse_array_reply` => Redis Arrays
    * `parse_nullable_str_reply` => Bulk Strings (when response may contain `nil`)
    * `parse_nullable_int_reply` => Redis Integers (when response may contain `nil`)
    * `parse_nullable_arr_reply` => for mixed response arrays, mostly `multi`/`exec` blocks
    * some commands return `NullableArrays`
* Geo Set API added

_TODO_:
* key-prefixing
* async pub/sub
* Clusters, Scripting need refactoring to pass tests
* create a clean benchmark suite
* cleanup readme/move to Documenter

## Basics (see runtests.jl)

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

Some Redis commands have a more complex syntax that allows for options to be passed to the command. Redis.jl supports these options through the use of a final varargs parameter to those functions (for example, `scan`). In these cases, the options should be passed as individual strings at the end of the function. As mentioned earlier, keywords or other Types can be passed for these options as well and will be coerced to `String`.

```
scan(conn, 0, "match", "foo*")
```

If users are interested, the API could be improved to provide custom functions for these complex commands.

An exception to this option syntax are the functions `zinterstore` and `zunionstore`, which have specific implementations to allow for ease of use due to their greater complexity.

## Pipelining

**add new doc**

## Transactions

**add new doc**

## Pub/sub -- blocking only

**add new doc**

## Sentinel

**add new doc**

## Cluster

**add doc**

## Streaming Scanners

In order to simplify use of the Redis scan commands, SCAN (keys), SSCAN (sets), ZSCAN (ordered sets), and HSCAN (hashes), an julia iterator interface is provided. To initialize a scan use the appropriate constructor:

`AllKeyScanner(conn::RedisConnection, match::AbstractString, count::Int)` : scan the redis key namesspace using redis `scan`

`KeyScanner(conn::RedisConnection, key::AbstractString, match::AbstractString, count::Int)` : scan a redis set, ordered set or hash using redis `sscan`. `zscan` or `hscan`

`match` is used for pattern matching, and defaults to "\*",  while `count` specifies the number of items returned per iteration and defaults to 1.

AN example scan through the redis key namespace
```
ks = allkeyscanner(conn, "test*", 10)
for k in ks
    println(ks)
end
```
TODO:   more scan iteration examples

Note the following caveats from the Redis documentation at http://redis.io/commands/scan:

    * The SCAN family of commands only offer limited guarantees about the returned elements since the collection
    that we incrementally iterate can change during the iteration process.

    * Basically with COUNT the user specified _the amount of work that should be done at every call in order to
      retrieve elements from the collection_. This is __just a hint__ for the implementation, however generally
      speaking this is what you could expect most of the times from the implementation.

__Please refer to the Redis documentation for more details.__

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

#### Sorted Sets
* `zrank(conn, "ordered_set", "non_existent_member")`
* `zrevrank(conn, "ordered_set", "non_existent_member")`
* `zscore(conn, "ordered_set", "non_existent_member")`

#### Hashes
* `hget(conn, "some_hash", "non_existent_field")`
* `hmget(conn, "some_hash", "nofield1", "nofield2")`
