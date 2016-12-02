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
    connectState = _isConnected(context) 
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