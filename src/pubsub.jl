function _subscribe(conn::SubscriptionConnection, channels::Array)
    do_command_wr(conn, unshift!(channels, "subscribe"))
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

function unsubscribe(conn::SubscriptionConnection, channels...)
    for channel in channels
        delete!(conn.callbacks, channel)
    end
    execute_command(conn, unshift!(channels, "unsubscribe"))
end

function _psubscribe(conn::SubscriptionConnection, patterns::Array)
    do_command_wr(conn, unshift!(patterns, "psubscribe"))
end

function psubscribe(conn::SubscriptionConnection, pattern::AbstractString, callback::Function)
    conn.callbacks[pattern] = callback
    _psubscribe(conn, [pattern])
end

function psubscribe(conn::SubscriptionConnection, subs::Dict{AbstractString, Function})
    for (pattern, callback) in subs
        conn.callbacks[pattern] = callback
    end
    _psubscribe(conn, collect(values(subs)))
end

function punsubscribe(conn::SubscriptionConnection, patterns...)
    for pattern in patterns
        delete!(conn.pcallbacks, pattern)
    end
    execute_command(conn, unshift!(patterns, "punsubscribe"))
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
