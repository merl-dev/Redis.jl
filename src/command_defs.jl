const EXEC = ["exec"]

baremodule Aggregate
    const NotSet = ""
    const Sum = "sum"
    const Min = "min"
    const Max = "max"
end

# Key commands
@redisfunction "del" key...
@redisfunction "unlink" key...
@redisfunction "touch" key... 
@redisfunction "dump" key
@redisfunction "exists" key
@redisfunction "expire" key seconds
@redisfunction "expireat" key timestamp

# CAUTION:  this command will block until all keys have been returned
@redisfunction "keys" pattern

@redisfunction "migrate" host port key destinationdb timeout
@redisfunction "move" key db
@redisfunction "persist" key
@redisfunction "pexpire" key milliseconds
@redisfunction "pexpireat" key millisecondstimestamp
@redisfunction "pttl" key
@redisfunction "randomkey"
@redisfunction "rename" key newkey
@redisfunction "renamenx" key newkey
@redisfunction "restore" key ttl serializedvalue
@redisfunction "scan" cursor::Integer options...
@redisfunction "sort" key options...
@redisfunction "ttl" key

Base.keytype(conn::RedisConnection, key) = do_command(conn, flatten_command("type", key))
Base.keytype(conn::TransactionConnection, key) = do_command(conn, flatten_command("type", key))

# String commands
@redisfunction "append" key value
@redisfunction "bitcount" key options...
@redisfunction "bitop" operation destkey key keys...
@redisfunction "bitpos" key bit options...
@redisfunction "decr" key
@redisfunction "decrby" key decrement
@redisfunction "get" key
@redisfunction "getbit" key offset
@redisfunction "getrange" key start finish
@redisfunction "getset" key value
@redisfunction "incr" key
@redisfunction "incrby" key increment::Integer

# Bulk string reply: the value of key after the increment,
# as per http://redis.io/commands/incrbyfloat
@redisfunction "incrbyfloat" key increment::Float64
@redisfunction "mget" key keys...
@redisfunction "mset" keyvalues
@redisfunction "msetnx" keyvalues
@redisfunction "psetex" key milliseconds value
@redisfunction "set" key value options...
@redisfunction "setbit" key offset value
@redisfunction "setex" key seconds value
@redisfunction "setnx" key value
@redisfunction "setrange" key offset value
@redisfunction "strlen" key

# Hash commands
@redisfunction "hdel" key field fields...
@redisfunction "hexists" key field
@redisfunction "hget" key field
@redisfunction "hgetall" key
@redisfunction "hincrby" key field increment::Integer

# Bulk string reply: the value of key after the increment,
# as per http://redis.io/commands/hincrbyfloat
@redisfunction "hincrbyfloat" key field increment::Float64

@redisfunction "hkeys" key
@redisfunction "hlen" key
@redisfunction "hmget" key field fields...
@redisfunction "hmset" key value
@redisfunction "hset" key field value
@redisfunction "hsetnx" key field value
@redisfunction "hvals" key
@redisfunction "hscan" key cursor::Integer options...

# List commands
@redisfunction "blpop" keys timeout
@redisfunction "brpop" keys timeout
@redisfunction "brpoplpush" source destination timeout
@redisfunction "lindex" key index
@redisfunction "linsert" key place pivot value
@redisfunction "llen" key
@redisfunction "lpop" key
@redisfunction "lpush" key value values...
@redisfunction "lpushx" key value
@redisfunction "lrange" key start finish
@redisfunction "lrem" key count value
@redisfunction "lset" key index value
@redisfunction "ltrim" key start finish
@redisfunction "rpop" key
@redisfunction "rpoplpush" source destination
@redisfunction "rpush" key value values...
@redisfunction "rpushx" key value

# Set commands
@redisfunction "sadd" key member members...
@redisfunction "scard" key
@redisfunction "sdiff" key keys...
@redisfunction "sdiffstore" destination key keys...
@redisfunction "sinter" key keys...
@redisfunction "sinterstore" destination key keys...
@redisfunction "sismember" key member

@redisfunction "smembers" key
@redisfunction "smove" source destination member
@redisfunction "spop" key
@redisfunction "srandmember" key
@redisfunction "srandmember" key count
@redisfunction "srem" key member members...
@redisfunction "sunion" key keys...
@redisfunction "sunionstore" destination key keys...
@redisfunction "sscan" key cursor::Integer options...

# Sorted set commands
#=
merl-dev: a number of methods were added to take AbstractString for score value
to enable score ranges like '(1 2,' or "-inf", "+inf",
as per docs http://redis.io/commands/zrangebyscore
=#

@redisfunction "zadd" key score::Number member::AbstractString

# NOTE:  using ZADD with Dicts could introduce bugs if some scores are identical
@redisfunction "zadd" key scorememberdict

#=
This following version of ZADD enables adding new members using `Tuple{Int64, AbstractString}` or
`Tuple{Float64, AbstractString}` for single or multiple additions to the sorted set without
resorting to the use of `Dict`, which cannot be used in the case where all entries have the same score.
=#
@redisfunction "zadd" key scoremembertup scorememberstup...

@redisfunction "zcard" key
@redisfunction "zcount" key min max

# Bulk string reply: the new score of member (a double precision floating point number),
# represented as string, as per http://redis.io/commands/zincrby
@redisfunction "zincrby" key increment member

@redisfunction "zlexcount" key min max
@redisfunction "zrange" key start finish options...
@redisfunction "zrangebylex" key min max options...
@redisfunction "zrangebyscore" key min max options...
@redisfunction "zrank" key member
@redisfunction "zrem" key member members...
@redisfunction "zremrangebylex" key min max
@redisfunction "zremrangebyrank" key start finish
@redisfunction "zremrangebyscore" key start finish
@redisfunction "zrevrange" key start finish options...
@redisfunction "zrevrangebyscore" key start finish options...
@redisfunction "zrevrank" key member
# ZCORE returns a Bulk string reply: the score of member (a double precision floating point
# number), represented as string.
@redisfunction "zscore" key member
@redisfunction "zscan" key cursor::Integer options...

function _build_store_internal(destination, numkeys, keys, weights, aggregate, command)
    length(keys) > 0 || throw(ClientException("Must supply at least one key"))
    suffix = AbstractString[]
    if length(weights) > 0
        suffix = map(string, weights)
        unshift!(suffix, "weights")
    end
    if aggregate != Aggregate.NotSet
        push!(suffix, "aggregate")
        push!(suffix, aggregate)
    end
    vcat([command, destination, string(numkeys)], keys, suffix)
end

# TODO: PipelineConnection and TransactionConnection
function zinterstore(conn::RedisConnectionBase, destination, numkeys,
    keys::Array, weights=[]; aggregate=Aggregate.NotSet)
    command = _build_store_internal(destination, numkeys, keys, weights, aggregate, "zinterstore")
    do_command(conn, command)
end

function zunionstore(conn::RedisConnectionBase, destination, numkeys::Integer,
    keys::Array, weights=[]; aggregate=Aggregate.NotSet)
    command = _build_store_internal(destination, numkeys, keys, weights, aggregate, "zunionstore")
    do_command(conn, command)
end

# HyperLogLog commands
@redisfunction "pfadd" key element elements...
@redisfunction "pfcount" key keys...
@redisfunction "pfmerge" destkey sourcekey sourcekeys...

# Connection commands
@redisfunction "auth" password
@redisfunction "echo" message
@redisfunction "ping"
@redisfunction "quit"
@redisfunction "select" index

function client_list(conn::RedisConnectionBase; asdict=false)
    clients = Redis.do_command(conn, "client list")
    if asdict
        results = Array{Dict{AbstractString, Any},1}()
        for client in split(clients, "\n")
            if length(client) > 0
                resulti = Dict{AbstractString, Any}()
                for asplit in split(client, " ")
                    kv = split(asplit, "=")
                    resulti[kv[1]] = kv[2]
                end
                push!(results, resulti)
            end
        end
        return results
    else
        return clients
    end
end

client_getname(conn::RedisConnectionBase) = do_command(conn, "client getname")

# Transaction commands
@redisfunction "discard"
@redisfunction "exec" 
@redisfunction "multi"
@redisfunction "unwatch"
@redisfunction "watch" key keys...

# Scripting commands
# TODO: PipelineConnection and TransactionConnection
function evalscript{T<:AbstractString}(conn::RedisConnection, script::T, numkeys::Integer, args::Array{T, 1})
    fc = flatten_command("eval", script, numkeys, args)
    do_command(conn, flatten_command("eval", script, numkeys, args))
end
evalscript{T<:AbstractString}(conn::RedisConnection, script::T) = evalscript(conn, script, 0, AbstractString[])

#################################################################
# TODO: NEED TO TEST BEYOND THIS POINT
@redisfunction "evalsha" sha1 numkeys keys args
@redisfunction "script_exists" script scripts...
@redisfunction "script_flush"
@redisfunction "script_kill" 
@redisfunction "script_load" script

# Server commands
@redisfunction "bgrewriteaof" 
@redisfunction "bgsave" 
@redisfunction "client_pause" timeout
@redisfunction "client_setname" name
@redisfunction "cluster_slots"
@redisfunction "command"
@redisfunction "command_count"
@redisfunction "command_info" command commands...
@redisfunction "config_get" parameter
@redisfunction "config_set" parameter value
@redisfunction "dbsize"
#@redisfunction "debug_segfault"
@redisfunction "flushall" 
@redisfunction "flushdb" 
@redisfunction "object" suncommand args...

function debug_object(conn::RedisConnectionBase, key; asdict=true)
    response = do_command(conn, "debug object $key")
    if asdict
        results = Dict{AbstractString, AbstractString}()
        for result in split(response, " ")[2:end]
            kv = split(result, ":")
            k = kv[1] == "at" ? "Value at" : kv[1]
            results[k] = kv[2]
        end
        results
    else
        response
    end
end

function info(conn::RedisConnectionBase; asdict=false)
    response = do_command(conn, "info")
    asdict ? _info(response) : response
end

function info(conn::RedisConnectionBase, section; asdict=false)
    response = do_command(conn, "info $section")
    asdict ? _info(response) : response
end

function _info(response)
    results = Dict{AbstractString, AbstractString}()
    for result in split(response, "\r\n")
        if length(result) > 0 && !contains(result, "#")
            kv = split(result, ":")
            results[kv[1]] = kv[2]
        end
    end
    results
end    

config_resetstat(conn::RedisConnectionBase) = do_command(conn, "config resetstat")

config_rewrite(conn::RedisConnectionBase) = do_command(conn, "config rewrite")

# TODO convert unix time stamp to DateTime
@redisfunction "lastsave"
@redisfunction "role"
@redisfunction "save" 
@redisfunction "slaveof" host port
@redisfunction "_time"

function shutdown(conn::RedisConnectionBase; save=true)
    if isConnected(conn).reply != REDIS_OK
        conn = restart(conn)
    end
    reply = ccall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}), conn.context,
        "shutdown " * ifelse(save, "save", "nosave"))
end

# Sentinel commands
@sentinelfunction "master" mastername
@sentinelfunction "reset" pattern
@sentinelfunction "failover" mastername
@sentinelfunction "monitor" name ip port quorum
@sentinelfunction "remove" name
@sentinelfunction "set" name option value

# Custom commands (PubSub/Transaction)
@redisfunction "publish" channel message
@redisfunction "pubsub" subcommand cmds...

#Need a specialized version of execute to keep the connection in the transaction state
function exec_transaction(conn::TransactionConnection)
    response = do_command(conn, EXEC)
    multi(conn)
    response
end

###############################################################
# The following Redis commands can be typecast to Julia structs
###############################################################

function time(c::RedisConnection)
    t = _time(c)
    s = parse(Int,t[1])
    ms = parse(Float64, t[2])
    s += (ms / 1e6)
    return unix2datetime(s)
end
