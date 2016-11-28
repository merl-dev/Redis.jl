###########################
# TODO:  pattern pub sub
#
###########################

type SubscriptionConnection <: SubscribableConnection
    parent::SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    callbacks::Dict{AbstractString, Function}
    pcallbacks::Dict{AbstractString, Function}
    context::Ptr{RedisContext}
    Q::Collections.PriorityQueue
end

function SubscriptionConnection(;parent::SubscribableConnection=RedisConnection())
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), parent.host, parent.port)
    connectState = _isConnected(context)
    if connectState.reply != REDIS_OK
        throw(ConnectionException(string("Failed to create subscription connection", connectState.msg)))
    else
        subscription_connection = SubscriptionConnection(parent, parent.host,
            parent.port, parent.password, parent.db, Dict{AbstractString, Function}(),
            Dict{AbstractString, Function}(), context, Collections.PriorityQueue())
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
    runloop = true
    while isConnected(conn).reply == REDIS_OK && runloop
        try
            if length(conn.Q) > 0 
                cmd = Collections.dequeue!(conn.Q)
                reply = ccall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}), conn.context, cmd)
                delete!(conn.callbacks, split(cmd, " ")[2])
                runloop = length(conn.callbacks) > 0
            elseif length(conn.callbacks) > 0 
                reply = @threadcall((:redisCommand, "libhiredis"), Ptr{RedisReply}, (Ptr{RedisContext}, Ptr{UInt8}), conn.context, "")
            else # nothing more to process
                exit()
            end
            jreply = Redis.get_result(reply)
            if (typeof(jreply)==Array{Any,1} && length(jreply) > 0 && jreply[1] == "unsubscribe")
                println(jreply)
            else
                message = Redis.SubscriptionMessage(jreply)
                if message.message_type == Redis.SubscriptionMessageType.Message
                    conn.callbacks[message.channel](message.message)
                elseif message.message_type == Redis.SubscriptionMessageType.Pmessage
                    conn.pcallbacks[message.channel](message.message)
                end
            end
        catch err
            err_callback(err)
        end
    end 
end

export startSubscriptionLoop, startSubscriptionLoopAsync 

function unsubscribe(conn::SubscriptionConnection, channels...)
    for channel in channels
        Collections.enqueue!(conn.Q, "unsubscribe $channel", 0)
        # fudge:  un-block the subscription message loop with an empty message
        publish(conn.parent, channel, "")
    end
end

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
