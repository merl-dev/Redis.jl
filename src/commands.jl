# Called by flatten_command. A `token` can be a String, Array, Set, Dict, or Tuple
export flatten

flatten(token::Number) = string(token)
flatten(token::AbstractString) = token

# function flatten(tokens::Array)
#     io = IOBuffer()
#     for item in tokens
#         write(io, flatten(item), " ")
#     end
#     String(take!(io))
# end

function flatten(token::Dict)
    r=Array{String,1}(length(token)*2)
    i=1
    for (k,v) in token
        r[i] = string(k)
        r[i+1] = string(v)
        i+=2
    end
    r
end


function flatten(token::Tuple{T, U}...) where {T<:Number, U<:AbstractString}
    r=AbstractString[]
    for item in token
        push!(r, string(item[1]))
        push!(r, item[2])
    end
    r
end

export flatten_command

flatten_command(command...) = vcat(map(flatten, command)...)

macro redisfunction(command, parser, args...)
    fn_name = esc(Symbol(command))
    command = split(command, '_')
    return quote
        function $(fn_name)(conn::RedisConnection, $(args...))
            command_str = flatten_command($(command...), $(args...))
            redis_command(conn, command_str, $parser)
        end

        # transaction connections always return a simple string "QUEUED"
        function $(fn_name)(conn::TransactionConnection, $(args...))
            command_str = flatten_command($(command...), $(args...))
            redis_command(conn, command_str, parse_string_reply)
        end

        # pipelined connections do not reply
        function $(fn_name)(conn::PipelineConnection, $(args...))
            command_str = flatten_command($(command...), $(args...))
            redis_command(conn, command_str)
            enqueue!(conn.parsers, $(parser))
            return
        end

    end
end

macro sentinelfunction(command, parser, args...)
    fn_name = esc(Symbol(string("sentinel_", command)))
    return quote
        function $(fn_name)(conn::SentinelConnection, $(args...))
            command_str = flatten_command("sentinel", $command, $(args...))
            redis_command(conn, command_str, $parser)
        end
    end
end

macro clusterfunction(command, parser, args...)
    fn_name = esc(Symbol(string("cluster_", command)))
    return quote
        function $(fn_name)(conn::RedisConnectionBase, $(args...))
            command_str = flatten_command("cluster", $command, $(args...))
            redis_command(conn, command_str, $parser)
        end
    end
end

function redis_command(conn::RedisConnectionBase, argv::Array{S,1}, parser::Function) where
            S<:AbstractString
    if !is_connected(conn)
        reconnect(conn)
    end
    reply = ccall((:redisCommandArgv, :libhiredis), Ptr{RedisReply}, (Ptr{RedisContext}, Int32, Ptr{Ptr{UInt8}},
                Ptr{UInt}), conn.context, length(argv), argv, C_NULL)
    r = unsafe_load(reply)
    s = parser(r)
    free_reply_object(reply)
    s
end

function redis_command(conn::RedisConnectionBase, command_str::String, parser::Function)
    if !is_connected(conn)
        reconnect(conn)
    end
    reply = ccall((:redisCommand, :libhiredis), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}),
        conn.context, command_str)
    r = unsafe_load(reply)
    s = parser(r)
    free_reply_object(reply)
    s
end

function redis_command(conn::RedisConnectionBase, command_str::String)
    if !is_connected(conn)
        reconnect(conn)
    end
    ccall((:redisCommand, :libhiredis), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}),
        conn.context, command_str)
end

function redis_command(conn::PipelineConnection, argv::Array{S,1}) where S<:AbstractString
    if !is_connected(conn)
        reconnect(conn)
    end
    ccall((:redisAppendCommandArgv, :libhiredis), Ptr{RedisReply}, (Ptr{RedisContext}, Int32, Ptr{Ptr{UInt8}},
            Ptr{UInt}), conn.context, length(argv), argv, C_NULL)
end

function redis_command(conn::PipelineConnection, command_str::String)
    if !is_connected(conn)
        reconnect(conn)
    end
    ccall((:redisAppendCommand, :libhiredis), Void, (Ptr{RedisContext}, Ptr{UInt8}),
        conn.context, command_str)
end

parse_string_reply(reply::RedisReply) =
    ccall(:jl_pchar_to_string, Ref{String}, (Ptr{UInt8}, Int), reply.str, reply.len)

function parse_nullable_str_reply(reply::RedisReply)
    if contains(==, STRING_REPLIES, reply.rtype)
        Nullable{String}(ccall(:jl_pchar_to_string, Ref{String}, (Ptr{UInt8}, Int),
            reply.str, reply.len))
    else
        Nullable{String}()
    end
end

parse_int_reply(reply::RedisReply) = reply.integer

parse_nullable_int_reply(reply::RedisReply) =
    reply.rtype == REPLY_NIL ? Nullable{Int}() : reply.integer

function parse_array_reply(reply::RedisReply)
    results = Array{String, 1}(0)
    # elements can be another array that we recurse into, or a bulk string
    replies = unsafe_wrap(Array, reply.element, reply.elements)
    for ix in 1:length(replies)
        ur = unsafe_load(replies[ix])
        if contains(==, STRING_REPLIES, ur.rtype)
            push!(results, parse_string_reply(ur))
        else
            rec = parse_array_reply(ur)
            for rix in 1:length(rec)
                push!(results, rec[rix])
            end
        end
    end
    results
end

function parse_nullable_arr_reply(reply::RedisReply)
    results = NullableArray{Union{String, Int}}(0)
    # elements can be another array that we recurse into, or a bulk string
    replies = unsafe_wrap(Array, reply.element, reply.elements)
    for ix in 1:length(replies)
        ur = unsafe_load(replies[ix])
        if contains(==, STRING_REPLIES, ur.rtype)
            push!(results, parse_string_reply(ur))
        elseif ur.rtype == REPLY_INTEGER
            push!(results, parse_nullable_int_reply(ur))
        elseif ur.rtype == REPLY_NIL
            push!(results, Nullable{String}())
        else
            rec = parse_nullable_arr_reply(ur)
            for rix in 1:length(rec)
                push!(results, rec[rix])
            end
        end
    end
    results
end

function Base.read(conn::PipelineConnection)
    @assert count(conn) > 0
    replyptr = Array{Ptr{RedisReply}, 1}(1)  # RedisRedply**
    reply = ccall((:redisGetReply, :libhiredis), Int32, (Ptr{RedisContext},
        Ptr{Ptr{RedisReply}}), conn.context, replyptr)
    if reply == REDIS_OK
        r = unsafe_load(replyptr[1])
        parsed_reply = dequeue!(conn.parsers)(r)
        free_reply_object(replyptr[1])
        return parsed_reply
    else
        throw(ServerException("server failed get_reply: ", "undetermined"))
    end
end

"Free memory allocated to objects returned from hiredis"
function free_reply_object(redisReply)
    ccall((:freeReplyObject, :libhiredis), Void, (Ptr{RedisReply},), redisReply)
end
