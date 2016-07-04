immutable RedisConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

immutable SentinelConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

immutable TransactionConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

type PipelineConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
    count::Integer
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

function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    try
        context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
        connection = RedisConnection(host, port, password, db, context)
        on_connect(connection)
    catch
        throw(ConnectionException("Failed to connect to Redis server"))
    end
end

function SentinelConnection(; host="127.0.0.1", port=26379, password="", db=0)
    try
        socket = connect(host, port)
        sentinel_connection = SentinelConnection(host, port, password, db, socket)
        on_connect(sentinel_connection)
    catch
        throw(ConnectionException("Failed to connect to Redis sentinel"))
    end
end

function TransactionConnection(parent::RedisConnection)
    try
        context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), parent.host, parent.port)
        transaction_connection = TransactionConnection(parent.host, parent.port, parent.password, parent.db, context)
        on_connect(transaction_connection)
    catch
        throw(ConnectionException("Failed to create transaction"))
    end
end

function PipelineConnection(parent::RedisConnection)
    try
        context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), parent.host, parent.port)
        pipeline_connection = PipelineConnection(parent.host, parent.port, parent.password, parent.db, context, 0)
        on_connect(pipeline_connection)
    catch
        throw(ConnectionException("Failed to create pipeline"))
    end
end

function SubscriptionConnection(parent::SubscribableConnection)
    try
        socket = connect(parent.host, parent.port)
        subscription_connection = SubscriptionConnection(parent.host,
            parent.port, parent.password, parent.db, Dict{AbstractString, Function}(),
            Dict{AbstractString, Function}(), socket)
        on_connect(subscription_connection)
    catch
        throw(ConnectionException("Failed to create subscription"))
    end
end

function on_connect(conn::RedisConnectionBase)
    conn.password != "" && auth(conn, conn.password)
    conn.db != 0        && select(conn, conn.db)
    conn
end

function disconnect(conn::RedisConnectionBase)
    if conn.context != 0 # isdefined(:redisContext)
        ccall((:redisFree, "libhiredis"), Void, (Ptr{RedisContext},), conn.context)
    end
end

# TODO: add arg checks
function restart(conn::RedisConnection)
    conn = RedisConnection(host=conn.host, port=conn.port, password=conn.password, db=conn.db)
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

function open_pipeline(conn::RedisConnection)
    PipelineConnection(conn)
end

function read_pipeline(conn::PipelineConnection)
    result = Any[]
    for i=1:conn.count
        push!(result, get_reply(conn))
    end
    conn.count = 0
    result
end

nullcb(err) = nothing
function open_subscription(conn::RedisConnection, err_callback=nullcb)
    s = SubscriptionConnection(conn)
    @async subscription_loop(s, err_callback)
    s
end

function subscription_loop(conn::SubscriptionConnection, err_callback::Function)
    while is_connected(conn)
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
