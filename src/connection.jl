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

struct RedisContext
    err::Int32
    errstr::Ptr{UInt8}
    fd::Int32
    flags::Int32
    obuf::Ptr{UInt8}
    reader::Ptr{RedisReader}
end

struct RedisConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

function show(io::IO, rc::RedisConnection)
    print(io, "    host: ", rc.host, "\n    port: ", rc.port, "\npassword: ", "****", "\n      db: ", rc.db, "\nRedisContext\n", unsafe_load(rc.context))
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
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    ctxt = unsafe_load(context)
    if ctxt.err != REDIS_OK
        #errptr = unsafe_string(ctxt.errstr) crashes
        throw(ConnectionException(string("Failed to connect to Redis server: ", "undertermined")))
    else
        connection = RedisConnection(host, port, password, db, context)
        on_connect(connection)
    end
end

struct ConnectReply
    reply::Int
    msg::AbstractString
end

# used internally
function _is_connected(context::Ptr{RedisContext})
    uc = unsafe_load(context)
    uc.err == REDIS_OK ? ConnectReply(uc.err, "") :
        ConnectReply(uc.err, "unknown connect failure, often host:port incorrect or
            redis-server not started")
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
Submitting another command with a closed connection will call `restart` on that connection.
"""
disconnect(conn::RedisConnectionBase) = ccall((:redisFree, "libhiredis"), Void, (Ptr{RedisContext},), conn.context)

restart(conn::RedisConnection) = RedisConnection(host=conn.host, port=conn.port, password=conn.password, db=conn.db)
