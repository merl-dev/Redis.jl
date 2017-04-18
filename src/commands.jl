# Called by flatten_command. A `token` can be a String, Array, Set, Dict, or Tuple
export flatten
flatten(token::Number) = string(token)
flatten(token::AbstractString) = token
flatten(token::Array) = map(string, token)

function flatten(token::Set)
    io = IOBuffer()
    for item in token
        write(io, flatten(item), " ")
    end
    String(take!(io))
end

function flatten(token::Dict)
    io = IOBuffer()
    for (k,v) in token
        write(io, flatten(k), " ")
        write(io, flatten(v), " ")
    end
    String(take!(io))
end

function flatten{T<:Number, U<:AbstractString}(token::Tuple{T, U}...)
    io = IOBuffer()
    for item in token
        write(io, flatten(item[1]), " ")
        write(io, flatten(item[2]), " ")
    end
    String(take!(io))
end

export flatten_command
function flatten_command(command...)
    io = IOBuffer()
    @inbounds for i in 1:length(command)
        write(io, flatten(command[i]), " ")
    end
    String(take!(io))
end

macro redisfunction(command, parser, args...)
    fn_name = esc(Symbol(command))
    command = split(command, '_')
    return quote
        function $(fn_name)(conn::RedisConnection, $(args...))
            if !is_connected(conn)
                conn = reconnect(conn)
            end
            command_str = flatten_command($(command...), $(args...))
            reply = redis_command(conn, command_str)
            r = unsafe_load(reply)
            s = $(parser)(r)
            free_reply_object(reply)
            return s
        end

        # transaction connections always return a simple string "QUEUED"
        function $(fn_name)(conn::TransactionConnection, $(args...))
            if !is_connected(conn)
                conn = reconnect(conn)
            end
            command_str = flatten_command($(command...), $(args...))
            reply = redis_command(conn, command_str)
            r = unsafe_load(reply)
            s = parse_string_reply(r)
            free_reply_object(reply)
            return s
        end

        # pipelined connections do not reply
        function $(fn_name)(conn::PipelineConnection, $(args...))
            if !is_connected(conn)
                conn = reconnect(conn)
            end
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
            if !is_connected(conn)
                conn = reconnect(conn)
            end
            command_str = flatten_command("sentinel", $command, $(args...))
            reply = redis_command(conn, command_str)
            r = unsafe_load(reply)
            s = $(parser)(r)
            free_reply_object(reply)
            return s
        end
    end
end

macro clusterfunction(command, parser, args...)
    fn_name = esc(Symbol(string("cluster_", command)))
    return quote
        function $(fn_name)(conn::RedisConnectionBase, $(args...))
            if !is_connected(conn)
                conn = reconnect(conn)
            end
            command_str = flatten_command("cluster", $command, $(args...))
            reply = redis_command(conn, command_str)
            r = unsafe_load(reply)
            s = $(parser)(r)
            free_reply_object(reply)
            return s
        end
    end
end

redis_command(conn::RedisConnectionBase, command_str::String) =
    ccall((:redisCommand, :libhiredis), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}),
        conn.context, command_str)

redis_command(conn::PipelineConnection, command_str::String) =
    ccall((:redisAppendCommand, :libhiredis), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}),
        conn.context, command_str)


parse_string_reply(reply::RedisReply) =
    ccall(:jl_pchar_to_string, Ref{String}, (Ptr{UInt8}, Int), reply.str, reply.len)

function parse_nullable_str_reply(reply::RedisReply)
    if reply.rtype == 1 || reply.rtype == 5 || reply.rtype == 6
        Nullable{String}(ccall(:jl_pchar_to_string, Ref{String}, (Ptr{UInt8}, Int),
            reply.str, reply.len))
    else
        Nullable{String}()
    end
end

parse_int_reply(reply::RedisReply) = reply.integer

parse_nullable_int_reply(reply::RedisReply) =
    reply.rtype == 4 ? Nullable{Int}() : reply.integer

function parse_array_reply(reply::RedisReply)
    results = Array{String, 1}(0)
    # elements can be another array that we recurse into, or a bulk string
    replies = unsafe_wrap(Array, reply.element, reply.elements)
    for ix in 1:length(replies)
        ur = unsafe_load(replies[ix])
        if ur.rtype == 1 || ur.rtype == 5 || ur.rtype == 6
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
        if ur.rtype == 1 || ur.rtype == 5 || ur.rtype == 6
            push!(results, parse_string_reply(ur))
        elseif ur.rtype == 3
            push!(results, parse_nullable_int_reply(ur))
        elseif ur.rtype == 4
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
