struct TransactionConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

"""
see `RedisConnection` for details
"""
function TransactionConnection(; host="127.0.0.1", port=6379, password="", db=0)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    connectState = _is_connected(context)
    if connectState.reply != REDIS_OK
        throw(ConnectionException(string("Failed to connect to Redis server: ", connectState.msg)))
    else
        connection = TransactionConnection(host, port, password, db, context)
        on_connect(connection)
    end
end
function TransactionConnection(parent::RedisConnection)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), parent.host, parent.port)
    connectState = _is_connected(context)
    if connectState.reply != REDIS_OK
        throw(ConnectionException(string("Failed to create transaction: ", connectState.msg)))
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
