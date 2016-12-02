immutable SentinelConnection <: SubscribableConnection
    host::AbstractString
    port::Integer
    password::AbstractString
    db::Integer
    context::Ptr{RedisContext}
end

#TODO - refac, document and test
function SentinelConnection(; host="127.0.0.1", port=26379, password="", db=0)
    try
        socket = connect(host, port)
        sentinel_connection = SentinelConnection(host, port, password, db, socket)
        on_connect(sentinel_connection)
    catch
        throw(ConnectionException("Failed to connect to Redis sentinel"))
    end
end

macro sentinelfunction(command, args...)
    func_name = esc(Symbol(string("sentinel_", command)))
    return quote
        $(func_name)(conn::SentinelConnection, $(args...)) =
            do_command(conn, flatten_command("sentinel", $command, $(args...)))
    end
end

sentinel_masters(conn::SentinelConnection) =
    do_command(conn, flatten_command("sentinel", "masters"))

sentinel_slaves(conn::SentinelConnection, mastername) =
    do_command(conn, flatten_command("sentinel", "slaves", mastername))

sentinel_getmasteraddrbyname(conn::SentinelConnection, mastername) =
    do_command(conn, flatten_command("sentinel", "get-master-addr-by-name", mastername))
