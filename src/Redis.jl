__precompile__(true)
module Redis

if isfile(joinpath(dirname(@__FILE__),"..","deps","deps.jl"))
    include("../deps/deps.jl")
else
    Pkg.build("Redis")
end

abstract RedisConnectionBase
abstract SubscribableConnection <: RedisConnectionBase

using Base.Dates

import Base.convert, Base.get, Base.keys, Base.time, DataStructures.OrderedSet

export RedisException, ConnectionException, ServerException, ProtocolException, ClientException
export RedisConnection, SentinelConnection, TransactionConnection, SubscriptionConnection,
       disconnect, isConnected, open_transaction, reset_transaction, open_subscription,
       open_pipeline, pipeline_command, read_pipeline, do_command
export RedisContext, RedisReply, RedisReader
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
export discard, exec, exec_transaction, multi, unwatch, watch
# Scripting commands
export evalscript, evalsha, script_exists, script_flush, script_kill, script_load
# PubSub commands
export subscribe, publish, psubscribe, punsubscribe, unsubscribe, pubsub
# Server commands (`info` command not exported due to conflicts with other packages)
export bgrewriteaof, bgsave, client_list, client_pause, client_getname, client_setname, 
       client_reply, cluster_slots, command, command_count, command_info, config_get, 
       config_resetstat, config_rewrite, config_set, dbsize, debug_object, object,
       flushall, flushdb, lastsave, role, save, shutdown, slaveof, time
# Sentinel commands
export sentinel_masters, sentinel_master, sentinel_slaves, sentinel_getmasteraddrbyname,
       sentinel_reset, sentinel_failover, sentinel_monitor, sentinel_remove, sentinel_set
# Streaming scanners
export StreamScanner, KeyScanner, SetScanner, OrderedSetScanner, HashScanner, next!, 
       collect, collectAsync!
# Redis constants
# TODO: add more, consider a separate constants.jl
export REDIS_PERSISTENT_KEY, REDIS_EXPIRED_KEY

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

include("libhiredis.jl")
include("exceptions.jl")
include("connection.jl")
include("pipeline.jl")
include("transaction.jl")
include("async.jl")
include("sentinel.jl")
include("pubsub.jl")
include("commands.jl")
include("command_defs.jl")
include("streamscan.jl")

end
