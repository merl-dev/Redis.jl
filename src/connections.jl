# RedisReadTask, ReplyObjectFunctions and RedisReader are defined here for those wishing to
# implement readers based on the hiredis library
struct RedisReadTask
    rtype::Int32
    elements::Int32
    idx::Int32
    obj::Ptr{Void}
    parent::Ptr{RedisReadTask}
    privdata::Ptr{Void}
end

create_string(task::Ptr{RedisReadTask}, str::Ptr{UInt8}, len::UInt) = C_NULL
create_array(task::Ptr{RedisReadTask}, len::Int32) = C_NULL
create_integer(task::Ptr{RedisReadTask}, int::Integer) = C_NULL
create_nil(task::Ptr{RedisReadTask}) = C_NULL
free_object(obj::Ptr{Void}) = C_NULL

const create_string_c = cfunction(create_string, Ptr{Void}, (Ptr{RedisReadTask}, Ptr{UInt8}, UInt))
const create_array_c = cfunction(create_array, Ptr{Void}, (Ptr{RedisReadTask}, Int32))
const create_integer_c = cfunction(create_integer, Ptr{Void}, (Ptr{RedisReadTask}, Int))
const create_nil_c = cfunction(create_nil, Ptr{Void}, (Ptr{RedisReadTask},))
const free_object_c = cfunction(free_object, Ptr{Void}, (Ptr{Void},))

struct RedisReplyObjectFunctions
    create_string_c
    create_array_c
    create_integer_c
    create_nil_c
    free_object_c
end

struct RedisReader
    err::Int32
    errstr::Ptr{UInt8}
    buf::Ptr{UInt8}
    pos::UInt
    len::UInt
    maxbuf::UInt
    rstack::Array{RedisReadTask, 1}
    ridx::Int32
    reply::Ptr{Void}
    fn::Ptr{RedisReplyObjectFunctions}
    privdata::Ptr{Void}
end

struct RedisReply
    rtype::Int32                  # REDIS_REPLY_*
    integer::Int64                # The integer when type is REDIS_REPLY_INTEGER, HiReds.jl bug: this was UInt64
    len::Int32                    # Length of string
    str::Ptr{UInt8}               # Used for both REDIS_REPLY_ERROR and REDIS_REPLY_STRING
    elements::UInt                # number of elements, for REDIS_REPLY_ARRAY
    element::Ptr{Ptr{RedisReply}} # elements vector for REDIS_REPLY_ARRAY
end

struct RedisContext
    err::Int32
    errstr::Ptr{UInt8}
    fd::Int32
    flags::Int32
    obuf::Ptr{UInt8}
    reader::Ptr{RedisReader}
end

abstract type RedisConnectionBase end
abstract type SubscribableConnection <: RedisConnectionBase end

struct RedisConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

function show(io::IO, rc::RedisConnectionBase)
    println(typeof(rc))
    println(io, "    host: ", rc.host)
    println(io, "    port: ", rc.port)
    println(io, "password: ", "****")
    println(io, "      db: ", rc.db)
end

"""
    RedisConnection(;host, port, password, db)

Establish a synchronous TCP connecion to the Redis Server using hiredis (and bypassing Julia's network IO).

# Arguments
* `host` : address of server, defaults to localhost
* `port` : port, defaults to 6379
* `password` : server password, defaults to empty String
* `db` : select the rRedis db, defaults to 0

Returns a RedisConnection object containing a pointer to a `RedisContext`, which holds state for a connection.
The `RedisContext` has an `err` field set to zero upon success, and `errstr` contains a String describing
the error upon failure.

Once successfully connected, an attempt is made to authorize and select the given db.
"""
function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    context = ccall((:redisConnect, :libhiredis), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    ctxt = unsafe_load(context)
    if ctxt.err != REDIS_OK
        #errptr = unsafe_string(ctxt.errstr) crashes
        throw(ConnectionException(string("Failed to connect to Redis server: ", "undertermined")))
    else
        connection = RedisConnection(host, port, password, db, context)
        on_connect(connection)
    end
end

"""
    is_connected(conn::RedisConnectionBase)

Test connection status.

# Arguments
* `conn` : a `RedisConnection`
"""
is_connected(conn::RedisConnectionBase) = unsafe_load(conn.context).err == REDIS_OK

"""
    on_connect(conn:RedisConnectionBase)

Upon connection requests authentication form the Redis server and selects
the approproate db.

# Arguments
* `conn` : a `RedisConnection`
* `auth` : an optional password
* `db`   : an optional db
"""
function on_connect(conn::RedisConnectionBase)
    conn.password != "" && auth(conn, conn.password)
    conn.db != 0        && select(conn, conn.db)
    conn
end

"""
        disconnect(conn::RedisConnectionBase)

Close any one of the four RedisConnectionBase types and release associated resources.

# Note
Submitting another command with a closed connection will call `reconnect` on that connection.
"""
disconnect(conn::RedisConnectionBase) =
    ccall((:redisFree, :libhiredis), Void, (Ptr{RedisContext},), conn.context)

function reconnect(conn::RedisConnectionBase)
    reply = ccall((:redisReconnect, :libhiredis), Ptr{RedisContext}, (Ptr{RedisContext},), conn.context)
    if reply != REDIS_OK
        throw(ConnectionException(string("Failed to reconnect to Redis server: ", "undertermined")))
    end
end

# the sole purpose of this connection type is to define a different set of parsers
# for all of the redis commands.
struct TransactionConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
    function TransactionConnection(; host="127.0.0.1", port=6379, password="", db=0)
        conn = RedisConnection(host=host, port=port, password=password, db=db)
        new(conn.host, conn.port, conn.password, conn.db, conn.context)
    end
end

# the sole purpose of this connection type is to define a different set of parsers
# for all of the redis commands. The `parsers` field consists of an Array of reply
# parsers called when the pipleine is read.
struct PipelineConnection <: RedisConnectionBase
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    parsers::Queue{Function}
    context::Ptr{RedisContext}
    function PipelineConnection(; host="127.0.0.1", port=6379, password="", db=0)
        conn = RedisConnection(host=host, port=port, password=password, db=db)
        new(conn.host, conn.port, conn.password, conn.db, Queue(Function), conn.context)
    end
end
Base.count(conn::PipelineConnection) = length(conn.parsers)
parsers(conn::PipelineConnection) = conn.parsers


struct SubscriptionConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    callbacks::Dict{AbstractString, Function}
    pcallbacks::Dict{AbstractString, Function}
    context::Ptr{RedisContext}
    function SubscriptionConnection(; host="127.0.0.1", port=6379, password="", db=0)
        conn = RedisConnection(host=host, port=port, password=password, db=db)
        new(conn.host, conn.port, conn.password, conn.db, Dict{AbstractString, Function}(),
            Dict{AbstractString, Function}(), conn.context)
    end
end

nullsccb(err) = println(err)

startSubscriptionLoop(conn::SubscriptionConnection, err_cb::Function) = _loop(conn, err_cb)

function _loop(conn::SubscriptionConnection, err_cb::Function)
    while is_connected(conn)
        try
            reply = redis_command(conn, "")
            r = unsafe_load(reply)
            message = Redis.SubscriptionMessage(parse_array_reply(r))
            if message.message_type == Redis.SubscriptionMessageType.Message
                conn.callbacks[message.channel](message.message)
            elseif message.message_type == Redis.SubscriptionMessageType.Pmessage
                conn.pcallbacks[message.channel](message.message)
            end
        catch err
            err_cb(err)
        end
    end
end

baremodule SubscriptionMessageType
    const Message = 0
    const Pmessage = 1
    const Other = 2
end

struct SubscriptionMessage
    message_type
    channel::AbstractString
    message::AbstractString

    function SubscriptionMessage(reply::AbstractArray)
        notification = reply
        message_type = notification[1]
        if message_type == "message"
            new(SubscriptionMessageType.Message, notification[2], notification[3])
        elseif message_type == "pmessage"
            new(SubscriptionMessageType.Pmessage, notification[2], notification[4])
        else
            new(SubscriptionMessageType.Other, "", "")
        end
    end
end

immutable SentinelConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
    function SentinelConnection(; host="127.0.0.1", port=6379, password="", db=0)
        conn = RedisConnection(host=host, port=port, password=password, db=db)
        new(conn.host, conn.port, conn.password, conn.db, conn.context)
    end
end
