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

"""
Appends commands to an output buffer. Pipelining is sending a batch of commands
to redis to be processed in bulk. It cuts down the number of network requests.
"""
function pipeline_command(conn::SubscribableConnection, command::AbstractString)
    if isConnected(conn).reply != REDIS_OK
        conn = restart(conn)
    end
    ccall((:redisAppendCommand, "libhiredis"), Int32, (Ptr{RedisContext}, Ptr{UInt8}), conn.context, command)
end

function pipeline_command{S<:AbstractString}(conn::SubscribableConnection, argv::Array{S, 1})
    if isConnected(conn).reply != REDIS_OK
        conn = restart(conn)
    end
    ccall((:redisAppendCommandArgv, "libhiredis"), Int32, (Ptr{RedisContext}, Int32, Ptr{Ptr{UInt8}}, Ptr{UInt}), conn.context, length(argv), argv, C_NULL)
end
