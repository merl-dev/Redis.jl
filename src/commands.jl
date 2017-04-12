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
                conn = restart(conn)
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
                conn = restart(conn)
            end
            command_str = flatten_command($command, $(args...))
            reply = redis_command(conn, command_str)
            r = unsafe_load(reply)
            s = parse_string_reply(r)
            free_reply_object(reply)
            return s
        end

        # function $(fn_name)(conn::PipelineConnection, $(args...))
        #     pipeline_command(conn, flatten_command($command, $(args...)))
        #     conn.count += 1
        # end
    end
end

struct RedisReply
    rtype::Int32                  # REDIS_REPLY_*
    integer::Int64                # The integer when type is REDIS_REPLY_INTEGER, HiReds.jl bug: this was UInt64
    len::Int32                    # Length of string
    str::Ptr{UInt8}               # Used for both REDIS_REPLY_ERROR and REDIS_REPLY_STRING
    elements::UInt                # number of elements, for REDIS_REPLY_ARRAY
    element::Ptr{Ptr{RedisReply}} # elements vector for REDIS_REPLY_ARRAY
end

redis_command(conn::RedisConnectionBase, command_str::String) =
    ccall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}),
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
            rec = parse_array_reply(ur)
            for rix in 1:length(rec)
                push!(results, rec[rix])
            end
        end
    end
    results
end
"Free memory allocated to objects returned from hiredis"
function free_reply_object(redisReply)
    ccall((:freeReplyObject, "libhiredis"), Void, (Ptr{RedisReply},), redisReply)
end
