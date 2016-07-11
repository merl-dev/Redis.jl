immutable RedisConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

"""
    RedisConnection(;host, port, password, db)

Establish a synchronous TCP connecion to the Redis Server using hiredis (and bypassing Julia's network IO).

# Arguments
* `host` : address of server, defaults to loclahost
* `port` : port, defaults to 6379
* `password` : server password, defaults to empty String
* `db` : select the rRedis db, defaults to 0

Returns a RedisConnection object containing a pointer to a `RedisContext`, which holds state for a connection.
The `RedisContext` has an `err` field set to zero upon success, and `errstr` contains a String describing
the error upon failure.

Once successfully connected, an attempt is made to authorize and select the given db.

TODO: parse error string, Async version
"""
function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    if !_isConnected(context)
        throw(ConnectionException("Failed to connect to Redis server"))
    else
        connection = RedisConnection(host, port, password, db, context)
        on_connect(connection)
    end
end

# used internally
function _isConnected(context::Ptr{RedisContext})
    uc = unsafe_load(context)
    uc.err == 0 ? true : false
end

"""
    isConnected(conn::RedisConnection)

Test connection status.

# Arguments
* `conn` : a `RedisConnection`
"""
isConnected(conn::RedisConnectionBase) = _isConnected(conn.context)

function on_connect(conn::RedisConnectionBase)
    conn.password != "" && auth(conn, conn.password)
    conn.db != 0        && select(conn, conn.db)
    conn
end

"""
        disconnect(conn::RedisConnectionBase)

Close any one of the four RedisConnectionBase types and release associated resources.

# Note
Submitting another command with a closed connection will call `restart` on that connection.
"""
disconnect(conn::RedisConnectionBase) = ccall((:redisFree, "libhiredis"), Void, (Ptr{RedisContext},), conn.context)

# refac so that `restart` uses only the fields of the given `conn` parameter, otherwise throws error.  That's implied
# by the 're' in restart.
restart(conn::RedisConnection) = RedisConnection(host=conn.host, port=conn.port, password=conn.password, db=conn.db)

immutable SentinelConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

#TODO - refac, document and test
function SentinelConnection(; host="127.0.0.1", port=26379, password="", db=0)
    try
        socket = connect(host, port)
        sentinel_connection = SentinelConnection(host, port, password, db, socket)
        on_connect(sentinel_connection)
    catch
        throw(ConnectionException("Failed to connect to Redis sentinel"))
    end
end

immutable TransactionConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

"""
see `RedisConnection` for details
"""
function TransactionConnection(parent::RedisConnection)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), parent.host, parent.port)
    if !isConnected(context)
        throw(ConnectionException("Failed to create transaction"))
    else
        transaction_connection = TransactionConnection(parent.host, parent.port, parent.password, parent.db, context)
        on_connect(transaction_connection)
    end
end

function open_transaction(conn::RedisConnection)
    t = TransactionConnection(conn)
    multi(t)
    t
end

function reset_transaction(conn::TransactionConnection)
    discard(conn)
    multi(conn)
end

type PipelineConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
    count::Integer
end

"""
see `RedisConnection` for details
"""
function PipelineConnection(parent::RedisConnection)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), parent.host, parent.port)
    if !_isConnected(context)
        throw(ConnectionException("Failed to create pipeline"))
    else
        pipeline_connection = PipelineConnection(parent.host, parent.port, parent.password, parent.db, context, 0)
        on_connect(pipeline_connection)
    end
end

open_pipeline(conn::RedisConnection) =  PipelineConnection(conn)

# nullable issues
function read_pipeline(conn::PipelineConnection)
    result = Any[]
    for i=1:conn.count
        push!(result, get_reply(conn))
    end
    conn.count = 0
    result
end

immutable SubscriptionConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    callbacks::Dict{AbstractString, Function}
    pcallbacks::Dict{AbstractString, Function}
    context::Ptr{RedisContext}
end

#TODO: refac, document and test
function SubscriptionConnection(parent::SubscribableConnection)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), parent.host, parent.port)
    if !_isConnected(context)
        throw(ConnectionException("Failed to create pipeline"))
    else
        subscription_connection = SubscriptionConnection(parent.host,
            parent.port, parent.password, parent.db, Dict{AbstractString, Function}(),
            Dict{AbstractString, Function}(), context)
        on_connect(subscription_connection)
    end
end

nullcb(err) = nothing
function open_subscription(conn::RedisConnection, err_callback=nullcb)
    s = SubscriptionConnection(conn)
    @async subscription_loop(s, err_callback)
    s
end

function subscription_loop(conn::SubscriptionConnection, err_callback::Function)
    while isConnected(conn)
        try
            l = getline(conn.socket)
            reply = parseline(l, conn.socket)
            message = SubscriptionMessage(reply)
            if message.message_type == SubscriptionMessageType.Message
                conn.callbacks[message.channel](message.message)
            elseif message.message_type == SubscriptionMessageType.Pmessage
                conn.pcallbacks[message.channel](message.message)
            end
        catch err
            err_callback(err)
        end
    end
end
