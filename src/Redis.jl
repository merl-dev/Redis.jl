__precompile__()

module Redis

if isfile(joinpath(dirname(@__FILE__),"..","deps","deps.jl"))
    include("../deps/deps.jl")
else
    Pkg.build("Redis")
end

using Base.Dates, DataStructures, NullableArrays

import Base: convert, get, keys, time, collect, ==, show, sort, start, done, next, eltype

export  RedisException,
        ConnectionException,
        ServerException,
        ProtocolException,
        ClientException,
        RedisContext,
        RedisReply,
        RedisReader,
        RedisConnection,
        TransactionConnection,
        PipelineConnection,
        read_pipeline,
        disconnect,
        is_connected,
        redis_command,
        parse_string_reply,
        parse_int_reply,
        parse_nullable_str_reply,
        parse_nullable_int_reply,
        parse_array_reply

# Key commands
export del, dump, exists, expire, expireat, keys,
       migrate, move, persist, pexpire, pexpireat,
       pttl, randomkey, rename, renamenx, restore,
       scan, sort, ttl, keytype, touch, unlink
# String commands
export append, bitcount, bitop, bitpos, decr, decrby,
       get, getbit, getrange, getset, incr, incrby,
       incrbyfloat, mget, mset, msetnx, psetex, set,
       setbit, setex, setnx, setrange, strlen
# Hash commands
export hdel, hexists, hget, hgetall, hincrby, hincrbyfloat,
       hkeys, hlen, hmget, hmset, hset, hsetnx, hvals,
       hscan
# List commands
export blpop, brpop, brpoplpush, lindex, linsert, llen,
       lpop, lpush, lpushx, lrange, lrem, lset,
       ltrim, rpop, rpoplpush, rpush, rpushx
# Set commands
export sadd, scard, sdiff, sdiffstore, sinter, sinterstore,
       sismember, smembers, smove, spop, srandmember, srem,
       sunion, sunionstore, sscan
# Sorted set commands
export zadd, zcard, zcount, zincrby, zinterstore, zlexcount,
       zrange, zrangebylex, zrangebyscore, zrank, zrem,
       zremrangebylex, zremrangebyrank, zremrangebyscore, zrevrange,
       zrevrangebyscore, zrevrank, zscore, zunionstore, zscan,
       Aggregate
# HyperLogLog commands
export pfadd, pfcount, pfmerge
# Connection commands
export auth, echo, ping, quit, select
# Transaction commands
export discard, exec, multi, unwatch, watch
# Scripting commands
export evalscript, evalsha, script_exists, script_flush, script_kill, script_load
# Server commands
export bgrewriteaof, bgsave, client_list, client_pause, client_getname, client_setname,
       client_reply, cluster_slots, command, command_count, command_info, config_get,
       config_resetstat, config_rewrite, config_set, dbsize, debug_object, object_refcount,
       object_idletime, object_encoding, flushall, flushdb, lastsave, role, save, shutdown,
       slaveof, time
# *SCAN Iterators
export AllKeyScanner, KeyScanner, start, next, done

const REDIS_ERR = -1
const REDIS_OK = 0

"define a default callback that does nothing"
nullcb(args) = nothing

"""
        convert(::Type{Dict{String, String}}, strvec::Vector{Any})

Helper converts redis reply vectors to `Dict`
"""
function convert(::Type{Dict{String, String}}, strvec::Vector{Any})
    resulti = Dict{String, String}()
    for i in 1:2:length(strvec)
        resulti[strvec[i]] = strvec[i+1]
    end
    resulti
end

include("exceptions.jl")
include("connections.jl")
include("commands.jl")
include("command_defs.jl")
include("scaniterators.jl")

end
