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
"""
function RedisConnection(; host="127.0.0.1", port=6379, password="", db=0)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    connectState = _isConnected(context) 
    if connectState.reply != REDIS_OK 
        throw(ConnectionException(string("Failed to connect to Redis server: ", connectState.msg)))
    else
        connection = RedisConnection(host, port, password, db, context)
        on_connect(connection)
    end
end

immutable ConnectReply
    reply::Int
    msg::AbstractString
end

# used internally
function _isConnected(context::Ptr{RedisContext})
    uc = unsafe_load(context)
    uc.err == REDIS_OK ? ConnectReply(uc.err, "") : ConnectReply(uc.err, "unknown connect failure, often host:port incorrect or redis-server not started")
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
