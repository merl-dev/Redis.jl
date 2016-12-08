immutable SentinelConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

function SentinelConnection(; host="127.0.0.1", port=26379, password="", db=0)
    context = ccall((:redisConnect, "libhiredis"), Ptr{RedisContext}, (Ptr{UInt8}, Int32), host, port)
    connectState = _isConnected(context) 
    if connectState.reply != REDIS_OK 
        throw(ConnectionException(string("Failed to connect to Redis Sentinel: ", connectState.msg)))
    else
        connection = SentinelConnection(host, port, password, db, context)
        on_connect(connection)
    end
end

macro sentinelfunction(command, args...)
    func_name = esc(Symbol(string("sentinel_", command)))
    return quote
        $(func_name)(conn::SentinelConnection, $(args...)) =
            do_command(conn, flatten_command("sentinel", $command, $(args...)))
    end
end

function sentinel_masters(conn::SentinelConnection; asdict=false)
    reply = do_command(conn, flatten_command("sentinel", "masters"))
    if asdict
        results = Array{Dictionary{AbstractString, AbstractString}}()
        for reparry in reply
            push!(results, convert(Dict{String, String}, reparry))
        end
        return results
    end

end

function sentinel_slaves(conn::SentinelConnection, mastername; asdict=false)
    reply = do_command(conn, flatten_command("sentinel", "slaves", mastername))
    if asdict
        results = Array{Dictionary{String, String}}()
        for reparry in reply
            push!(results, convert(Dict{String, String}, reparry))
        end
        return results
    end
end

sentinel_getmasteraddrbyname(conn::SentinelConnection, mastername) =
    do_command(conn, flatten_command("sentinel", "get-master-addr-by-name", mastername))

