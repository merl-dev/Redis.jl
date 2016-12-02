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
    #uc.err == REDIS_OK ? ConnectReply(uc.err, "") : ConnectReply(uc.err, unsafe_string(uc.errstr))
    uc.err == REDIS_OK ? ConnectReply(uc.err, "") : ConnectReply(uc.err, "unknown connect failure, often host:port incorrect or redis-server not started")
end

"""
    isConnected(conn::RedisConnection)

Test connection status.

# Arguments
* `conn` : a `RedisConnection`
"""
function isConnected(conn::RedisConnectionBase) 
    _isConnected(conn.context)
end

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
    connectState = _isConnected(context)
    if connectState.reply != REDIS_OK
        throw(ConnectionException(string("Failed to create pipeline", connectState.msg)))
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