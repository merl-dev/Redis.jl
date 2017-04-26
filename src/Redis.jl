__precompile__()

module Redis

if isfile(joinpath(dirname(@__FILE__),"..","deps","deps.jl"))
    include("../deps/deps.jl")
else
    Pkg.build("Redis")
end

using Base.Dates, DataStructures, NullableArrays

import Base: info, get, keys, time, collect, ==, show, sort, start, done, next, eltype,
        quit, select, touch, dump

export  RedisException,
        ConnectionException,
        ServerException,
        ProtocolException,
        ClientException,
        RedisContext,
        RedisReply,
        RedisReader,
        RedisConnection,
        @redisfunction,
        TransactionConnection,
        PipelineConnection,
        SubscriptionConnection,
        SentinelConnection,
        @sentinelfunction,
        @clusterfunction,
        disconnect,
        is_connected,
        redis_command,
        resp,
        parse_string_reply,
        parse_int_reply,
        parse_array_reply,
        parse_nullable_str_reply,
        parse_nullable_int_reply

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
       client_reply, client_kill_addr, client_kill_filt, cluster_slots, command,
       command_count, command_info, config_get, config_resetstat, config_rewrite,
       config_set, dbsize, debug_object, object_refcount, debug_sleep, object_idletime,
       object_encoding, flushall, flushdb, lastsave, role, save, shutdown, slaveof, time
# *SCAN Iterators
export AllKeyScanner, KeyScanner, start, next, done
# Pipeline commands
export  read_pipeline
# Pub/Sub commands
export  subscribe,
        psubscribe,
        startSubscriptionLoop,
        publish,
        pubsub
# Latency commands
export  latency_latest,
        latency_history,
        latency_reset,
        latency_doctor
# Sentinel commands
export  sentinel_master,
        sentinel_masters,
        sentinel_slaves,
        sentinel_sentinels,
        sentinel_reset,
        sentinel_failover,
        sentinel_ckquorum,
        sentinel_flushconfig,
        sentinel_monitor,
        sentinel_remove,
        sentinel_set,
        sentinel_getmasteraddrbyname
# Geo commands
export  geoadd,
        geohash,
        geopos,
        geodist,
        georadius,
        georadiusbymember
# Cluster commands
export  cluster_info,
        cluster_addslots,
        cluster_delslots,
        cluster_getkeysinslot,
        cluster_meet,
        cluster_reset,
        cluster_setslot,
        cluster_countfailurereports,
        cluster_failover,
        cluster_nodes,
        cluster_saveconfig,
        cluster_slaves,
        cluster_countkeysinslot,
        cluster_forget,
        cluster_keyslot,
        cluster_replicate,
        cluster_setconfigepoch,
        cluster_slots

const REDIS_ERR = -1
const REDIS_OK = 0
const REPLY_STRING = 1
const REPLY_ARRAY = 2
const REPLY_INTEGER = 3
const REPLY_NIL = 4
const REPLY_STATUS = 5
const REPLY_ERR = 6
const STRING_REPLIES = [REPLY_STRING, REPLY_STATUS, REPLY_ERR]

"define a default callback that does nothing"
nullcb(args) = nothing

include("exceptions.jl")
include("connections.jl")
include("commands.jl")
include("command_defs.jl")
include("scaniterators.jl")

end
