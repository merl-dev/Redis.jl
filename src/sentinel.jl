
macro sentinelfunction(command, ret_type, args...)
    func_name = esc(Symbol(string("sentinel_", command)))
    return quote
        function $(func_name)(conn::SentinelConnection, $(args...))
            response = execute_command(conn, flatten_command("sentinel", $command, $(args...)))
            convert_response($ret_type, response)
        end
    end
end

function sentinel_masters(conn::SentinelConnection)
    response = execute_command(conn, flatten_command("sentinel", "masters"))
    [convert_response(Dict, master) for master in response]
end

function sentinel_slaves(conn::SentinelConnection, mastername)
    response = execute_command(conn, flatten_command("sentinel", "slaves", mastername))
    [convert_response(Dict, slave) for slave in response]
end

function sentinel_getmasteraddrbyname(conn::SentinelConnection, mastername)
    execute_command(conn, flatten_command("sentinel", "get-master-addr-by-name", mastername))
end
