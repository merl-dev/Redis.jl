const EXEC = ["exec"]

baremodule Aggregate
    const NotSet = ""
    const Sum = "sum"
    const Min = "min"
    const Max = "max"
end

# Key commands
@redisfunction "del" Integer key...
@redisfunction "dump" AbstractString key
@redisfunction "exists" Bool key
@redisfunction "expire" Bool key seconds
@redisfunction "expireat" Bool key timestamp

# CAUTION:  this command will block until all keys have been returned
@redisfunction "keys" Set{AbstractString} pattern

@redisfunction "migrate" Bool host port key destinationdb timeout
@redisfunction "move" Bool key db
@redisfunction "persist" Bool key
@redisfunction "pexpire" Bool key milliseconds
@redisfunction "pexpireat" Bool key millisecondstimestamp
@redisfunction "pttl" Integer key
@redisfunction "randomkey" Nullable{AbstractString}
@redisfunction "rename" AbstractString key newkey
@redisfunction "renamenx" Bool key newkey
@redisfunction "restore" Bool key ttl serializedvalue
@redisfunction "scan" Array{Any, 1} cursor::Integer options...
@redisfunction "sort" Array{AbstractString, 1} key options...
@redisfunction "ttl" Integer key
function Base.keytype(conn::RedisConnection, key)
    response = do_command(conn, flatten_command("type", key))
    #convert_response(AbstractString, response)
end
function Base.keytype(conn::TransactionConnection, key)
    do_command(conn, flatten_command("type", key))
end

# String commands
@redisfunction "append" Integer key value
@redisfunction "bitcount" Integer key options...
@redisfunction "bitop" Integer operation destkey key keys...
@redisfunction "bitpos" Integer key bit options...
@redisfunction "decr" Integer key
@redisfunction "decrby" Integer key decrement
@redisfunction "get" Nullable{AbstractString} key
@redisfunction "getbit" Integer key offset
@redisfunction "getrange" AbstractString key start finish
@redisfunction "getset" AbstractString key value
@redisfunction "incr" Integer key
@redisfunction "incrby" Integer key increment::Integer

# Bulk string reply: the value of key after the increment,
# as per http://redis.io/commands/incrbyfloat
@redisfunction "incrbyfloat" AbstractString key increment::Float64
@redisfunction "mget" Array{Nullable{AbstractString}, 1} key keys...
@redisfunction "mset" Bool keyvalues
@redisfunction "msetnx" Bool keyvalues
@redisfunction "psetex" AbstractString key milliseconds value
@redisfunction "set" AbstractString key value options...
@redisfunction "setbit" Integer key offset value
@redisfunction "setex" AbstractString key seconds value
@redisfunction "setnx" AbstractString key value
@redisfunction "setrange" Integer key offset value
@redisfunction "strlen" Integer key

# Hash commands
@redisfunction "hdel" Integer key field fields...
@redisfunction "hexists" Bool key field
@redisfunction "hget" Nullable{AbstractString} key field
@redisfunction "hgetall" Dict{AbstractString, AbstractString} key
@redisfunction "hincrby" Integer key field increment::Integer

# Bulk string reply: the value of key after the increment,
# as per http://redis.io/commands/hincrbyfloat
@redisfunction "hincrbyfloat" AbstractString key field increment::Float64

@redisfunction "hkeys" Array{AbstractString, 1} key
@redisfunction "hlen" Integer key
@redisfunction "hmget" Array{Nullable{AbstractString}, 1} key field fields...
@redisfunction "hmset" AbstractString key value
@redisfunction "hset" Bool key field value
@redisfunction "hsetnx" Bool key field value
@redisfunction "hvals" Array{AbstractString, 1} key
@redisfunction "hscan" Tuple{AbstractString, Dict{AbstractString, AbstractString}} key cursor::Integer options...

# List commands
@redisfunction "blpop" Array{AbstractString, 1} keys timeout
@redisfunction "brpop" Array{AbstractString, 1} keys timeout
@redisfunction "brpoplpush" AbstractString source destination timeout
@redisfunction "lindex" Nullable{AbstractString} key index
@redisfunction "linsert" Integer key place pivot value
@redisfunction "llen" Integer key
@redisfunction "lpop" Nullable{AbstractString} key
@redisfunction "lpush" Integer key value values...
@redisfunction "lpushx" Integer key value
@redisfunction "lrange" Array{AbstractString, 1} key start finish
@redisfunction "lrem" Integer key count value
@redisfunction "lset" AbstractString key index value
@redisfunction "ltrim" AbstractString key start finish
@redisfunction "rpop" Nullable{AbstractString} key
@redisfunction "rpoplpush" Nullable{AbstractString} source destination
@redisfunction "rpush" Integer key value values...
@redisfunction "rpushx" Integer key value

# Set commands
@redisfunction "sadd" Integer key member members...
@redisfunction "scard" Integer key
@redisfunction "sdiff" Set{AbstractString} key keys...
@redisfunction "sdiffstore" Integer destination key keys...
@redisfunction "sinter" Set{AbstractString} key keys...
@redisfunction "sinterstore" Integer destination key keys...
@redisfunction "sismember" Bool key member

@redisfunction "smembers" Set{AbstractString} key
@redisfunction "smove" Bool source destination member
@redisfunction "spop" Nullable{AbstractString} key
@redisfunction "srandmember" Nullable{AbstractString} key
@redisfunction "srandmember" Set{AbstractString} key count
@redisfunction "srem" Integer key member members...
@redisfunction "sunion" Set{AbstractString} key keys...
@redisfunction "sunionstore" Integer destination key keys...
@redisfunction "sscan" Tuple{AbstractString, Set{AbstractString}} key cursor::Integer options...

# Sorted set commands
#=
merl-dev: a number of methods were added to take AbstractString for score value
to enable score ranges like '(1 2,' or "-inf", "+inf",
as per docs http://redis.io/commands/zrangebyscore
=#

@redisfunction "zadd" Integer key score::Number member::AbstractString

# NOTE:  using ZADD with Dicts could introduce bugs if some scores are identical
@redisfunction "zadd" Integer key scorememberdict

#=
This following version of ZADD enables adding new members using `Tuple{Int64, AbstractString}` or
`Tuple{Float64, AbstractString}` for single or multiple additions to the sorted set without
resorting to the use of `Dict`, which cannot be used in the case where all entries have the same score.
=#
@redisfunction "zadd" Integer key scoremembertup scorememberstup...

@redisfunction "zcard" Integer key
@redisfunction "zcount" Integer key min max

# Bulk string reply: the new score of member (a double precision floating point number),
# represented as string, as per http://redis.io/commands/zincrby
@redisfunction "zincrby" AbstractString key increment member

@redisfunction "zlexcount" Integer key min max
@redisfunction "zrange" OrderedSet{AbstractString} key start finish options...
@redisfunction "zrangebylex" OrderedSet{AbstractString} key min max options...
@redisfunction "zrangebyscore" OrderedSet{AbstractString} key min max options...
@redisfunction "zrank" Nullable{Integer} key member
@redisfunction "zrem" Integer key member members...
@redisfunction "zremrangebylex" Integer key min max
@redisfunction "zremrangebyrank" Integer key start finish
@redisfunction "zremrangebyscore" Integer key start finish
@redisfunction "zrevrange" OrderedSet{AbstractString} key start finish options...
@redisfunction "zrevrangebyscore" OrderedSet{AbstractString} key start finish options...
@redisfunction "zrevrank" Nullable{Integer} key member
# ZCORE returns a Bulk string reply: the score of member (a double precision floating point
# number), represented as string.
@redisfunction "zscore" Nullable{AbstractString} key member
@redisfunction "zscan" Tuple{AbstractString, OrderedSet{AbstractString}} key cursor::Integer options...

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
@redisfunction "pfadd" Bool key element elements...
@redisfunction "pfcount" Integer key keys...
@redisfunction "pfmerge" AbstractString destkey sourcekey sourcekeys...

# Connection commands
@redisfunction "auth" AbstractString password
@redisfunction "echo" AbstractString message
@redisfunction "ping" AbstractString
@redisfunction "quit" AbstractString
@redisfunction "select" AbstractString index

function client_list(conn::RedisConnectionBase)
    clients = split(Redis.do_command(conn, "client list"), "\n")
    results = Array{Dict{AbstractString, Any},1}()
    for client in clients
        if length(client) > 0
            resulti = Dict{AbstractString, Any}()
            splits = split(client, " ")
            for asplit in splits
                kv = split(asplit, "=")
                resulti[kv[1]] = kv[2]
            end
            push!(results, resulti)
        end
    end
    results
end

# Transaction commands
@redisfunction "discard" Bool
@redisfunction "exec" Array{Bool} # only one element ever in this array?
@redisfunction "multi" Bool
@redisfunction "unwatch" Bool
@redisfunction "watch" Bool key keys...

# Scripting commands
# TODO: PipelineConnection and TransactionConnection
function evalscript{T<:AbstractString}(conn::RedisConnection, script::T, numkeys::Integer, args::Array{T, 1})
    fc = flatten_command("eval", script, numkeys, args)
    response = do_command(conn, flatten_command("eval", script, numkeys, args))
    convert_eval_response(Any, response)
end
evalscript{T<:AbstractString}(conn::RedisConnection, script::T) = evalscript(conn, script, 0, AbstractString[])

#################################################################
# TODO: NEED TO TEST BEYOND THIS POINT
@redisfunction "evalsha" Any sha1 numkeys keys args
@redisfunction "script_exists" Array script scripts...
@redisfunction "script_flush" AbstractString
@redisfunction "script_kill" AbstractString
@redisfunction "script_load" AbstractString script

# Server commands
@redisfunction "bgrewriteaof" AbstractString
@redisfunction "bgsave" AbstractString
@redisfunction "client_getname" AbstractString
@redisfunction "client_pause" Bool timeout
@redisfunction "client_setname" Bool name
@redisfunction "cluster_slots" Array{Any, 1}
@redisfunction "command" Array{Any,1}
@redisfunction "command_count" Integer
@redisfunction "command_info" Array{Any, 1} command commands...
@redisfunction "config_get" Array{Any, 1} parameter
@redisfunction "config_resetstat" Bool
@redisfunction "config_rewrite" Bool
@redisfunction "config_set" Bool parameter value
@redisfunction "dbsize" Integer
@redisfunction "debug_object" AbstractString key
@redisfunction "debug_segfault" Any
@redisfunction "flushall" AbstractString
@redisfunction "flushdb" AbstractString

# TODO: write methods formatting response
@redisfunction "info" AbstractString
@redisfunction "info" AbstractString section

# TODO convert unix time stamp to DateTime
@redisfunction "lastsave" Integer

@redisfunction "role" Array{Any,1}
@redisfunction "save" AbstractString
@redisfunction "slaveof" AbstractString host port
@redisfunction "_time" Array{AbstractString, 1}

function shutdown(conn::RedisConnectionBase; save=true)
    if isConnected(conn).reply != REDIS_OK
        conn = restart(conn)
    end
    reply = ccall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}), conn.context,
        "shutdown " * ifelse(save, "save", "nosave"))
end

# Sentinel commands
@sentinelfunction "master" Dict{AbstractString, AbstractString} mastername
@sentinelfunction "reset" Integer pattern
@sentinelfunction "failover" Any mastername
@sentinelfunction "monitor" Bool name ip port quorum
@sentinelfunction "remove" Bool name
@sentinelfunction "set" Bool name option value

# Custom commands (PubSub/Transaction)
@redisfunction "publish" Integer channel message
@redisfunction "pubsub" Array{Any, 1} subcommand

#Need a specialized version of execute to keep the connection in the transaction state
function exec(conn::TransactionConnection)
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
