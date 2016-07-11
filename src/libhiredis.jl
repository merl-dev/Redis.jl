const REDIS_ERR = -1
const REDIS_OK = 0
const REDIS_REPLY_STRING = 1
const REDIS_REPLY_ARRAY = 2
const REDIS_REPLY_INTEGER = 3
const REDIS_REPLY_NIL = 4
const REDIS_REPLY_STATUS = 5
const REDIS_REPLY_ERROR = 6

immutable RedisReadTask
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

immutable RedisReplyObjectFunctions
    create_string_c
    create_array_c
    create_integer_c
    create_nil_c
    free_object_c
end

immutable RedisReader
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

type TcpStruct
    host
    source_addr
    port
end

immutable RedisContext
    err::Int32
    errstr::Ptr{UInt8}
    fd::Int32
    flags::Int32
    obuf::Ptr{UInt8}
    reader::Ptr{RedisReader}
end

immutable RedisReply
    rtype::Int32                  # REDIS_REPLY_*
    integer::Int64                # The integer when type is REDIS_REPLY_INTEGER, HiReds.jl bug: this was UInt64
    len::Int32                    # Length of string
    str::Ptr{UInt8}               # Used for both REDIS_REPLY_ERROR and REDIS_REPLY_STRING
    elements::UInt                # number of elements, for REDIS_REPLY_ARRAY
    element::Ptr{Ptr{RedisReply}} # elements vector for REDIS_REPLY_ARRAY
end

"Free memory allocated to objects returned from hiredis"
function free_reply_object(redisReply)
    ccall((:freeReplyObject, "libhiredis"), Void, (Ptr{RedisReply},), redisReply)
end

"""
In a blocking context, this function first checks if there are unconsumed
replies to return and returns one if so. Otherwise, it flushes the output
buffer to the socket and reads until it has a reply.
"""
function call_get_reply(conn::SubscribableConnection, redisReply::Array{Ptr{RedisReply}, 1})
    ccall((:redisGetReply, "libhiredis"), Int32, (Ptr{RedisContext}, Ptr{Ptr{RedisReply}}), conn.context, redisReply)
end

"""
Calls call_get_reply and returns one Array with all reponses.
"""
function get_reply(conn::SubscribableConnection)
    redisReply = Array{Ptr{RedisReply}, 1}(1)  # RedisRedply**
    if call_get_reply(conn, redisReply) == REDIS_OK
        conn.count = 0
    end
    get_result(redisReply[1])
end

# if VERSION <= v"0.4.9"
    """
    Converts the reply object from hiredis into a String, int, or Array as appropriate the the reply type.

    TODO: refac
    """
    function get_result(redisReply::Ptr{RedisReply})
        r = unsafe_load(redisReply)
        if r.rtype == REDIS_REPLY_STATUS
            ret = bytestring(r.str)
        elseif r.rtype == REDIS_REPLY_STRING
            ret = bytestring(r.str)
        elseif r.rtype == REDIS_REPLY_INTEGER
            ret = Int(r.integer)
        elseif r.rtype == REDIS_REPLY_ARRAY
            no = Int(r.elements)
            results = Union{Nullable{AbstractString},AbstractString}[]
            resultsi = Union{Nullable{AbstractString}, AbstractString}[] # if there is an inner array
            replies = pointer_to_array(r.element, no)
            for i in 1:no
                ro = unsafe_load(replies[i])
                if ro.rtype == REDIS_REPLY_STRING
                    push!(results, bytestring(ro.str))
                elseif ro.rtype == REDIS_REPLY_NIL
                    push!(results, Nullable{AbstractString}())
                else
                    ni = Int(ro.elements)
                    repliesi = pointer_to_array(ro.element, ni)
                    for j in 1:ni
                        rj = unsafe_load(repliesi[j])
                        if rj.rtype == REDIS_REPLY_STRING
                            push!(resultsi, bytestring(rj.str))
                        else ro.rtype == REDIS_REPLY_NIL
                            push!(resultsi, Nullable{AbstractString}())
                        end
                    end
                end
            end
            ret = length(resultsi) == 0 ? results : (results, resultsi)
        elseif r.rtype == REDIS_REPLY_ERROR
            error(bytestring(r.str))
        else
            ret = Nullable{AbstractString}()
        end
        free_reply_object(redisReply)
        ret
    end
# else
#     """
#     Converts the reply object from hiredis into a String, int, or Array
#     as appropriate the the reply type.
#     """
#     function get_result(redisReply::Ptr{RedisReply})
#         r = unsafe_load(redisReply)
#         if r.rtype == REDIS_REPLY_ERROR
#             error(unsafe_string(r.str))
#         end
#         ret = Nullable{AbstractString}(nothing)
#         if r.rtype == REDIS_OK || r.rtype == REDIS_REPLY_STRING
#             ret = unsafe_string(r.str)
#         elseif r.rtype == REDIS_REPLY_INTEGER
#             ret = Int64(r.integer)
#         elseif r.rtype == REDIS_REPLY_ARRAY
#             n = Int64(r.elements)
#             results = Vector{Union{AbstractString,Nullable{AbstractString}}}(n)
#             replies = unsafe_wrap(Array, r.element, n)
#             for i in 1:n
#                 ri = unsafe_load(replies[i])
#                 results[i] = ri.str == C_NULL ? Nullable{AbstractString}() : unsafe_string(ri.str)
#             end
#             ret = results
#         end
#         free_reply_object(redisReply)
#         ret
#     end
# end

"Pipelines a block of ordinary blocking calls."
macro pipeline(expr::Expr)
    Expr(:block, map(x ->
        begin
            if x.args[1] in names(HiRedis)
                args = copy(x.args)
                push!(args, Expr(:kw, :pipeline, true))
                Expr(x.head, args...)
            else
                x
            end
        end, filter(x -> typeof(x) == Expr, expr.args))...)
end
