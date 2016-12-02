type AsyncConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    callback::Function
    context::Ptr{RedisContext}
end

function AsyncConnection(;host="127.0.0.1", port=6379, password="", db=0)
    context = ccall((:redisAsyncConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    connectState = _isConnected(context) 
    if connectState.reply != REDIS_OK
        throw(ConnectionException(string("Failed to create asynchronous connection", connectState.msg)))
    else
        async_connection = AsyncConnection(host, port, password, db, nullcb, context)
        on_connect(async_connection)
    end
end

export AsyncConnection

