# @testset "Pub/Sub" begin
#       g(y) = print(y)
#       x = Any[]
#       f(y) = begin push!(x, y); println("channel func f: ", y) end
#       h(y) = begin push!(x, y); println("channel func h: ", y) end
#       subs = SubscriptionConnection()
#       subscribe(subs, "channel", f)
#       subscribe(subs, "duplicate", f)
#       
#       @test publish(conn, "channel", "hello, world!") == 1
#       sleep(2)
#       @test x == ["hello, world!"]
#
#     # following command prints ("Invalid response received: ")
#     disconnect(subs)
# end

type SubscriptionConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    callbacks::Dict{AbstractString, Function}
    pcallbacks::Dict{AbstractString, Function}
    context::Ptr{RedisContext}
    count::Integer
end

function SubscriptionConnection(;host="127.0.0.1", port=6379, password="", db=0)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    if !_isConnected(context)
        throw(ConnectionException("Failed to create subscription connection"))
    else
        subscription_connection = SubscriptionConnection(host,
            port, password, db, Dict{AbstractString, Function}(),
            Dict{AbstractString, Function}(), context, 0)
        on_connect(subscription_connection)
    end
end

function _subscribe(conn::SubscriptionConnection, channels::Array)
    msgs = []
    for channel in channels
        reply = ccall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}), conn.context, "subscribe $channel")
        push!(msgs, get_result(reply))
    end
    msgs
end

function subscribe(conn::SubscriptionConnection, channel::AbstractString, callback::Function)
    conn.callbacks[channel] = callback
    _subscribe(conn, [channel])
end


function subscribe(conn::SubscriptionConnection, subs::Dict{AbstractString, Function})
    for (channel, callback) in subs
        conn.callbacks[channel] = callback
    end
    _subscribe(conn, collect(keys(subs)))
end

nullsccb(err) = println(err)

startSubscriptionLoop(conn::SubscriptionConnection, err_callback::Function) = 
   _loop(conn, err_callback)

startSubscriptionLoopAsync(conn::SubscriptionConnection, err_callback::Function) = 
   @async _loop(conn, err_callback) 

function _loop(conn::SubscriptionConnection, err_callback::Function)
    while isConnected(conn)
        try
            reply = get_reply(conn)
            message = SubscriptionMessage(reply)
            if message.message_type == SubscriptionMessageType.Message
                conn.callbacks[message.channel](message.message)
            elseif message.message_type == SubscriptionMessageType.Pmessage
                conn.pcallbacks[message.channel](message.message)
            end
        catch err
            err_callback(err)
        end
    end 
end

export startSubscriptionLoop, startSubscriptionLoopAsync 

function unsubscribe(conn::SubscriptionConnection, channels...)
    for channel in channels
        delete!(conn.callbacks, channel)
        reply = ccall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}), conn.context, "unsubscribe $channel")
        #get_result(reply)
    end
end

###########################
# TODO:  pattern pub sub
#
###########################

baremodule SubscriptionMessageType
    const Message = 0
    const Pmessage = 1
    const Other = 2
end

immutable SubscriptionMessage
    message_type
    channel::AbstractString
    message::AbstractString

    function SubscriptionMessage(reply::AbstractArray)
        notification = reply
        message_type = notification[1]
        if message_type == "message"
            new(SubscriptionMessageType.Message, notification[2], notification[3])
        elseif message_type == "pmessage"
            new(SubscriptionMessageType.Pmessage, notification[2], notification[4])
        else
            new(SubscriptionMessageType.Other, "", "")
        end
    end
end
