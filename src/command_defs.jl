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

Base.keytype(conn::RedisConnectionBase, key) =
    redis_command(conn, string("type", " ", key), parse_string_reply)

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
    suffix = Array{String, 1}(0)
    if length(weights) > 0
        suffix = map(string, weights)
        unshift!(suffix, "weights")
    end
    aggregate != Aggregate.NotSet && push!(suffix, "aggregate", aggregate)
    vcat([command, destination, string(numkeys)], keys, suffix)
end

# TODO: PipelineConnection and TransactionConnection
function zinterstore(conn::RedisConnection, destination, numkeys, keys::Array,
            weights=[]; aggregate=Aggregate.NotSet)
    command = _build_store_internal(destination, numkeys, keys, weights, aggregate, "zinterstore")
    command_str = flatten_command(command...)
    redis_command(conn, command_str, parse_int_reply)
end

function zunionstore(conn::RedisConnection, destination, numkeys::Integer, keys::Array,
        weights=[]; aggregate=Aggregate.NotSet)
    command = _build_store_internal(destination, numkeys, keys, weights, aggregate, "zunionstore")
    command_str = flatten_command(command...)
    redis_command(conn, command_str, parse_int_reply)
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

multi(trans::TransactionConnection) =
    redis_command(trans, "multi", parse_string_reply)

exec(trans::TransactionConnection) =
    redis_command(trans, "exec", parse_nullable_arr_reply)

discard(trans::TransactionConnection) =
    redis_command(trans, "discard", parse_string_reply)

function watch(trans::TransactionConnection, keys...)
    command_str = flatten_command("watch", keys...)
    redis_command(trans, command_str, parse_string_reply)
end

unwatch(trans::TransactionConnection) =
    redis_command(trans, "unwatch", parse_string_reply)

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

client_kill_addr(conn::RedisConnectionBase, addr, port) =
    redis_command(conn, "client kill $addr:$port", parse_string_reply)

client_kill_filt(conn::RedisConnectionBase, filters::Dict{T, T}) where {T<:AbstractString} =
    redis_command(conn, string("client kill ", flatten(filters)), parse_int_reply)

function client_list(conn::RedisConnectionBase; asdict=false)
    clients = redis_command(conn, "client list", parse_nullable_str_reply)

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
client_getname(conn::RedisConnectionBase) = 
    redis_command(conn, "client getname", parse_nullable_str_reply)

@redisfunction "client_setname" parse_string_reply name

@redisfunction "command" parse_array_reply
command_count(conn::RedisConnectionBase) = 
    redis_command(conn, "command count", parse_int_reply)

@redisfunction "command_info" parse_array_reply command commands...
function config_get(conn::RedisConnectionBase, parameter; asdict=true)
    response = redis_command(conn, "config get $parameter", parse_array_reply)

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
config_resetstat(conn::RedisConnectionBase) = 
    redis_command(conn, "config resetstat", parse_string_reply)
config_rewrite(conn::RedisConnectionBase) = 
    redis_command(conn, "config rewrite", parse_string_reply)    
@redisfunction "dbsize" parse_int_reply
@redisfunction "flushall" parse_string_reply
@redisfunction "flushdb" parse_string_reply
@redisfunction "object_refcount" parse_nullable_int_reply key
@redisfunction "object_idletime" parse_nullable_int_reply key
@redisfunction "object_encoding" parse_nullable_str_reply key
@redisfunction "debug_sleep" parse_int_reply interval
function debug_object(conn::RedisConnectionBase, key; asdict=true)
    response = redis_command(conn, string("debug object ", key), parse_string_reply)

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
    response = redis_command(conn, "info", parse_nullable_str_reply)
    asdict ? _info(response) : response
end

function info(conn::RedisConnectionBase, section; asdict=true)
    response = redis_command(conn, "info $section", parse_nullable_str_reply)
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

@redisfunction "lastsave" parse_int_reply
@redisfunction "role" parse_nullable_arr_reply
@redisfunction "save" parse_string_reply
@redisfunction "slaveof" parse_string_reply host port
@redisfunction "time" parse_array_reply

# PubSub
function _subscribe(conn::SubscriptionConnection, channels::Array)
    msgs = Array{String, 1}(0)
    for channel in channels
        reply = redis_command(conn, "subscribe $channel", parse_string_reply)
        push!(msgs, reply)
    end
    msgs
end

function subscribe(conn::SubscriptionConnection, channel::AbstractString, callback::Function)
    conn.callbacks[channel] = callback
    _subscribe(conn, [channel])
end

function subscribe(conn::SubscriptionConnection, subs::Dict{AbstractString, Function})
    for (channel, callback) in subs
        conn.callbacks[channel] = callback
    end
    _subscribe(conn, collect(keys(subs)))
end

function _psubscribe(conn::SubscriptionConnection, channels::Array)
    msgs = Array{String, 1}(0)
    for channel in channels
        reply = redis_command(conn, "psubscribe $channel", parse_string_reply)
        push!(msgs, reply)
    end
    msgs
end

function psubscribe(conn::SubscriptionConnection, channel::AbstractString, callback::Function)
    conn.pcallbacks[channel] = callback
    _psubscribe(conn, [channel])
end

function psubscribe(conn::SubscriptionConnection, subs::Dict{AbstractString, Function})
    for (channel, callback) in subs
        conn.pcallbacks[channel] = callback
    end
    _psubscribe(conn, collect(keys(subs)))
end

@redisfunction "publish" parse_int_reply channel message
@redisfunction "pubsub" parse_array_reply subcommand cmds...

# Latency monitoring
# Report the latest latency events logged
@redisfunction "latency_latest" parse_nullable_arr_reply
@redisfunction "latency_history" parse_nullable_arr_reply eventname
@redisfunction "latency_reset" parse_int_reply eventnames...
@redisfunction "latency_doctor" parse_string_reply

# Sentinel commands
# Show the state and info of the specified master
@sentinelfunction "master" parse_array_reply mastername
# Show a list of monitored masters and their state
@sentinelfunction "masters" parse_array_reply
# Show a list of slaves for this master, and their state
@sentinelfunction "slaves" parse_array_reply mastername
# Show a list of sentinel instances for this master, and their state
@sentinelfunction "sentinels" parse_array_reply mastername
# Reset all the masters with matching name
@sentinelfunction "reset" parse_int_reply pattern
# Force a failover as if the master was not reachable, and without asking for agreement
@sentinelfunction "failover" parse_string_reply mastername
# Check if the current Sentinel configuration is able to reach the quorum needed to
# failover a master, and the majority needed to authorize the failover
@sentinelfunction "ckquorum" parse_string_reply mastername
# Force Sentinel to rewrite its configuration on disk, including the current Sentinel state
@sentinelfunction "flushconfig" parse_string_reply
# Start monitoring a new master with the specified name, ip, port, and quorum
@sentinelfunction "monitor" parse_string_reply name ip port quorum
# Remove the specified master
@sentinelfunction "remove" parse_string_reply name
# Change configuration parameters of a specific master. Multiple option / value pairs can
# be specified (or none at all). All the configuration parameters that can be configured
# via sentinel.conf are also configurable using the SET command
@sentinelfunction "set" parse_string_reply name option value
# Return the ip and port number of the master with that name
function sentinel_getmasteraddrbyname(conn::SentinelConnection, mastername)
    command_str = flatten_command("sentinel", "get-master-addr-by-name", mastername)
    redis_command(conn, command_str, parse_array_reply)
end

# Geo commands
@redisfunction "geoadd" parse_int_reply key longitude latitude member...
@redisfunction "geohash" parse_array_reply key member...
@redisfunction "geopos" parse_nullable_arr_reply key member...
@redisfunction "geodist" parse_nullable_str_reply key member1 member2...
@redisfunction "georadius" parse_array_reply key longitude latitude radius units options...
@redisfunction "georadiusbymember" parse_array_reply key member radius units options...

# Cluster commands
#@redisfunction "cluster_slots" parse_array_reply
@clusterfunction "addslots" parse_string_reply slots...
@clusterfunction "delslots" parse_string_reply slots...
@clusterfunction "getkeysinslot" parse_array_reply slot count
@clusterfunction "meet" parse_string_reply ip port
@clusterfunction "reset" parse_string_reply drasticness
@clusterfunction "setslot" parse_string_reply slot subcommand...
@clusterfunction "countfailurereports" parse_int_reply nodeid
@clusterfunction "failover" parse_string_reply failovertype
@clusterfunction "saveconfig" parse_string_reply
@clusterfunction "countkeysinslot" parse_int_reply slot
@clusterfunction "forget" parse_string_reply nodeid
@clusterfunction "keyslot" parse_int_reply key
@clusterfunction "replicate" parse_string_reply nodeid
@clusterfunction "setconfigepoch" parse_string_reply epoch
@clusterfunction "slots" parse_nullable_arr_reply
function cluster_slaves(conn, nodeid)
    reply = redis_command(conn, "cluster nodes", parse_string_reply)
    split(reply, '\n')[1:end-1]
end

function cluster_nodes(conn)
    reply = redis_command(conn, "cluster nodes", parse_string_reply)
    lines = split(reply, '\n')[1:end-1]

end

function cluster_info(conn::RedisConnectionBase; asdict=true)
    response = redis_command(conn, "cluster info", parse_string_reply)
    lines = split(response, "\r\n")
    if asdict
        results = Dict{AbstractString, AbstractString}()
        for line in lines[1:end-1]
            splits = split(line, ":")
            results[splits[1]] = splits[2]
        end
        results
    else
        response
    end
end
