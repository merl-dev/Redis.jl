baremodule Aggregate
    const NotSet = ""
    const Sum = "sum"
    const Min = "min"
    const Max = "max"
end

# Key commands
@redisfunction "del" parse_int_reply key...
@redisfunction "unlink" parse_int_reply key...
@redisfunction "touch" parse_int_reply key...
@redisfunction "dump" parse_string_reply key
@redisfunction "exists" parse_int_reply key
@redisfunction "expire" parse_int_reply key seconds
@redisfunction "expireat" parse_int_reply key timestamp
@redisfunction "keys" parse_array_reply pattern
@redisfunction "get" parse_nullable_str_reply key
@redisfunction "set" parse_string_reply key value options...
@redisfunction "migrate" parse_string_reply host port key destinationdb timeout
@redisfunction "move" parse_int_reply key db
@redisfunction "persist" parse_int_reply key
@redisfunction "pexpire" parse_int_reply key milliseconds
@redisfunction "pexpireat" parse_int_reply key millisecondstimestamp
@redisfunction "pttl" parse_int_reply key
@redisfunction "randomkey" parse_nullable_str_reply
@redisfunction "rename" parse_string_reply key newkey
@redisfunction "renamenx" parse_int_reply key newkey
@redisfunction "restore" parse_string_reply key ttl serializedvalue
@redisfunction "scan" parse_array_reply cursor options...
@redisfunction "sort" parse_array_reply key options...
@redisfunction "ttl" parse_int_reply key

function Base.keytype(conn::RedisConnectionBase, key)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, string("type", " ", key))
    r = unsafe_load(reply)
    s = parse_string_reply(r)
    free_reply_object(reply)
    return s
end

# String commands
@redisfunction "append" parse_int_reply key value
@redisfunction "bitcount" parse_int_reply key options...
@redisfunction "bitop" parse_int_reply operation destkey key keys...
@redisfunction "bitpos" parse_int_reply key bit options...
@redisfunction "decr" parse_int_reply key
@redisfunction "decrby" parse_int_reply key decrement
@redisfunction "getbit" parse_int_reply key offset
@redisfunction "getrange" parse_nullable_str_reply key start finish
@redisfunction "getset" parse_nullable_str_reply key value
@redisfunction "incr" parse_int_reply key
@redisfunction "incrby" parse_int_reply key increment::Integer
@redisfunction "incrbyfloat" parse_nullable_str_reply key increment::Float64
@redisfunction "mget" parse_array_reply key keys...
@redisfunction "mset" parse_string_reply keyvalues
@redisfunction "msetnx" parse_int_reply keyvalues
@redisfunction "psetex" parse_string_reply key milliseconds value
@redisfunction "setbit" parse_int_reply key offset value
@redisfunction "setex" parse_string_reply key seconds value
@redisfunction "setnx" parse_int_reply key value
@redisfunction "setrange" parse_int_reply key offset value
@redisfunction "strlen" parse_int_reply key

# Hash commands
@redisfunction "hdel" parse_int_reply key field fields...
@redisfunction "hexists" parse_int_reply key field
@redisfunction "hget" parse_nullable_str_reply key field
@redisfunction "hgetall" parse_array_reply key
@redisfunction "hincrby" parse_int_reply key field increment::Integer
@redisfunction "hincrbyfloat" parse_nullable_str_reply key field increment::Float64
@redisfunction "hkeys" parse_array_reply key
@redisfunction "hlen" parse_int_reply key
@redisfunction "hmget" parse_array_reply key field fields...
@redisfunction "hmset" parse_string_reply key value
@redisfunction "hset" parse_int_reply key field value
@redisfunction "hsetnx" parse_int_reply key field value
@redisfunction "hvals" parse_array_reply key
@redisfunction "hscan" parse_array_reply key cursor options...

# List commands
@redisfunction "blpop" parse_array_reply keys timeout
@redisfunction "brpop" parse_array_reply keys timeout
@redisfunction "brpoplpush" parse_nullable_str_reply source destination timeout
@redisfunction "lindex" parse_nullable_str_reply key index
@redisfunction "linsert" parse_int_reply key place pivot value
@redisfunction "llen" parse_int_reply key
@redisfunction "lpop" parse_nullable_str_reply key
@redisfunction "lpush" parse_int_reply key value values...
@redisfunction "lpushx" parse_int_reply key value
@redisfunction "lrange" parse_array_reply key start finish
@redisfunction "lrem" parse_int_reply key count value
@redisfunction "lset" parse_string_reply key index value
@redisfunction "ltrim" parse_string_reply key start finish
@redisfunction "rpop" parse_nullable_str_reply key
@redisfunction "rpoplpush" parse_nullable_str_reply source destination
@redisfunction "rpush" parse_int_reply key value values...
@redisfunction "rpushx" parse_int_reply key value

# Set commands
@redisfunction "sadd" parse_int_reply key member members...
@redisfunction "scard" parse_int_reply key
@redisfunction "sdiff" parse_array_reply key keys...
@redisfunction "sdiffstore" parse_int_reply destination key keys...
@redisfunction "sinter" parse_array_reply key keys...
@redisfunction "sinterstore" parse_int_reply destination key keys...
@redisfunction "sismember" parse_int_reply key member
@redisfunction "smembers" parse_array_reply key
@redisfunction "smove" parse_int_reply source destination member
@redisfunction "spop" parse_nullable_str_reply key
@redisfunction "srandmember" parse_nullable_str_reply key
@redisfunction "srandmember" parse_array_reply key count
@redisfunction "srem" parse_int_reply key member members...
@redisfunction "sunion" parse_array_reply key keys...
@redisfunction "sunionstore" parse_int_reply destination key keys...
@redisfunction "sscan" parse_array_reply key cursor options...

@redisfunction "zadd" parse_int_reply key score::Number member::AbstractString
@redisfunction "zadd" parse_int_reply key scorememberdict
@redisfunction "zadd" parse_int_reply key scoremembertup scorememberstup...

@redisfunction "zcard" parse_int_reply key
@redisfunction "zcount" parse_int_reply key min max
@redisfunction "zincrby" parse_nullable_str_reply key increment member
@redisfunction "zlexcount" parse_int_reply key min max
@redisfunction "zrange" parse_array_reply key start finish options...
@redisfunction "zrangebylex" parse_array_reply key min max options...
@redisfunction "zrangebyscore" parse_array_reply key min max options...
@redisfunction "zrank" parse_nullable_int_reply key member
@redisfunction "zrem" parse_int_reply key member members...
@redisfunction "zremrangebylex" parse_int_reply key min max
@redisfunction "zremrangebyrank" parse_int_reply key start finish
@redisfunction "zremrangebyscore" parse_int_reply key start finish
@redisfunction "zrevrange" parse_array_reply key start finish options...
@redisfunction "zrevrangebyscore" parse_array_reply key start finish options...
@redisfunction "zrevrank" parse_nullable_int_reply key member
@redisfunction "zscore" parse_nullable_str_reply key member
@redisfunction "zscan" parse_array_reply key cursor options...

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
function zinterstore(conn::RedisConnection, destination, numkeys, keys::Array,
            weights=[]; aggregate=Aggregate.NotSet)
    command = _build_store_internal(destination, numkeys, keys, weights, aggregate, "zinterstore")
    if !is_connected(conn)
        conn = restart(conn)
    end
    command_str = flatten_command(command...)
    reply = redis_command(conn, command_str)
    r = unsafe_load(reply)
    s = parse_int_reply(r)
    free_reply_object(reply)
    return s
end

function zunionstore(conn::RedisConnection, destination, numkeys::Integer, keys::Array,
        weights=[]; aggregate=Aggregate.NotSet)
    command = _build_store_internal(destination, numkeys, keys, weights, aggregate, "zunionstore")
    if !is_connected(conn)
        conn = restart(conn)
    end
    command_str = flatten_command(command...)
    reply = redis_command(conn, command_str)
    r = unsafe_load(reply)
    s = parse_int_reply(r)
    free_reply_object(reply)
    return s

end

# HyperLogLog commands
@redisfunction "pfadd" parse_int_reply key element elements...
@redisfunction "pfcount" parse_int_reply key keys...
@redisfunction "pfmerge" parse_string_reply destkey sourcekey sourcekeys...

# Connection commands
@redisfunction "auth" parse_string_reply password
@redisfunction "echo" parse_string_reply message
@redisfunction "ping" parse_string_reply
@redisfunction "quit" parse_string_reply
@redisfunction "select" parse_string_reply index

# Transaction commands require a TransactionConnection
function multi(trans::TransactionConnection)
    if !is_connected(trans)
        trans = restart(trans)
    end
    reply = redis_command(trans, "multi")
    r = unsafe_load(reply)
    pr = parse_string_reply(r)
    free_reply_object(reply)
    pr
end

function exec(trans::TransactionConnection)
    if !is_connected(trans)
        trans = restart(trans)
    end
    reply = redis_command(trans, "exec")
    r = unsafe_load(reply)
    pr = parse_nullable_arr_reply(r)
    free_reply_object(reply)
    pr
end

function discard(trans::TransactionConnection)
    if !is_connected(trans)
        trans = restart(trans)
    end
    reply = redis_command(trans, "discard")
    r = unsafe_load(reply)
    pr = parse_string_reply(r)
    free_reply_object(reply)
    pr
end

function watch(trans::TransactionConnection, keys...)
    if !is_connected(trans)
        trans = restart(trans)
    end
    command_str = flatten_command("watch", keys...)
    reply = redis_command(trans, command_str)
    r = unsafe_load(reply)
    pr = parse_string_reply(r)
    free_reply_object(reply)
    pr
end

function unwatch(trans::TransactionConnection)
    if !is_connected(trans)
        trans = restart(trans)
    end
    reply = redis_command(trans, "unwatch")
    r = unsafe_load(reply)
    pr = parse_string_reply(r)
    free_reply_object(reply)
    pr
end

# Scripting
@redisfunction "evalsha" parse_nullable_str_reply sha1 numkeys keys args
@redisfunction "script_exists" parse_array_reply script scripts...
@redisfunction "script_flush" parse_string_reply
@redisfunction "script_kill" parse_string_reply
@redisfunction "script_load" parse_nullable_str_reply script

# Server commands
@redisfunction "bgrewriteaof" parse_string_reply
@redisfunction "bgsave" parse_string_reply
@redisfunction "client_pause" parse_string_reply timeout

function client_list(conn::RedisConnectionBase; asdict=false)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, "client list")
    r = unsafe_load(reply)
    clients = parse_nullable_str_reply(r)
    free_reply_object(reply)

    if asdict
        results = Array{Dict{AbstractString, Any},1}()
        for client in split(get(clients), "\n")
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
@redisfunction "client_getname" parse_nullable_str_reply
@redisfunction "client_setname" parse_string_reply name
@redisfunction "cluster_slots" parse_array_reply
@redisfunction "command" parse_array_reply
@redisfunction "command_count" parse_int_reply
@redisfunction "command_info" parse_array_reply command commands...
#@redisfunction "config_get" parse_array_reply parameter
function config_get(conn::RedisConnectionBase, parameter; asdict=true)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, "config get $parameter")
    r = unsafe_load(reply)
    response = parse_array_reply(r)
    free_reply_object(reply)

    if asdict
        results = Dict{AbstractString, AbstractString}()
        for i = 1:2: length(response)
            results[response[i]] = response[i+1]
        end
        results
    else
        response
    end
end
@redisfunction "config_set" parse_string_reply parameter value...
@redisfunction "config_resetstat" parse_string_reply
@redisfunction "config_rewrite" parse_string_reply
@redisfunction "dbsize" parse_int_reply
#@redisfunction "debug_segfault"
@redisfunction "flushall" parse_string_reply
@redisfunction "flushdb" parse_string_reply

function object_refcount(conn::RedisConnectionBase, key)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, string("object refcount ", key))
    r = unsafe_load(reply)
    i = parse_nullable_int_reply(r)
    free_reply_object(reply)
    return i
end

function object_idletime(conn::RedisConnectionBase, key)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, string("object idletime ", key))
    r = unsafe_load(reply)
    i = parse_nullable_int_reply(r)
    free_reply_object(reply)
    return i
end

function object_encoding(conn::RedisConnectionBase, key)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, string("object encoding ", key))
    r = unsafe_load(reply)
    s = parse_nullable_str_reply(r)
    free_reply_object(reply)
    return s
end

function debug_object(conn::RedisConnectionBase, key; asdict=true)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, string("debug object ", key))
    r = unsafe_load(reply)
    response = parse_string_reply(r)
    free_reply_object(reply)

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

function info(conn::RedisConnectionBase; asdict=true)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, "info")
    r = unsafe_load(reply)
    response = parse_nullable_str_reply(r)
    free_reply_object(reply)

    asdict ? _info(response) : response
end

function info(conn::RedisConnectionBase, section; asdict=true)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = redis_command(conn, "info $section")
    r = unsafe_load(reply)
    response = parse_nullable_str_reply(r)
    free_reply_object(reply)
    asdict ? _info(response) : response
end

function _info(response)
    results = Dict{AbstractString, AbstractString}()
    for result in split(get(response), "\r\n")
        if length(result) > 0 && !contains(result, "#")
            kv = split(result, ":")
            results[kv[1]] = kv[2]
        end
    end
    results
end

# TODO convert unix time stamp to DateTime
@redisfunction "lastsave" parse_int_reply
@redisfunction "role" parse_nullable_arr_reply
@redisfunction "save" parse_string_reply
@redisfunction "slaveof" parse_string_reply host port
@redisfunction "time" parse_array_reply

function shutdown(conn::RedisConnectionBase; save=true)
    if !is_connected(conn)
        conn = restart(conn)
    end
    reply = ccall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}), conn.context,
        "shutdown " * ifelse(save, "save", "nosave"))
end

# Custom commands (PubSub/Transaction)
@redisfunction "publish" parse_int_reply channel message
@redisfunction "pubsub" parse_array_reply subcommand cmds...

function Base.time(conn::RedisConnectionBase)
    if !is_connected(conn)
        conn = restart(conn)
    end
    tm = config_rewrite(conn)
    s = parse(Int,tm[1])
    ms = parse(Float64, tm[2])
    s += (ms / 1e6)
    return unix2datetime(s)
end
