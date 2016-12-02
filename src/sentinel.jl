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
