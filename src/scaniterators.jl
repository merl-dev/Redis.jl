export allkeyscanner, keyscanner, results

import Base: start, next, done, eltype, length

abstract type ScanIterator end

iteratorsize{T<:ScanIterator}(::Type{T}) = SizeUnknown()
eltype{T<:ScanIterator}(::Type{T}) = String
start{T<:ScanIterator}(ks::T) = 1
done{T<:ScanIterator}(ks::T, state) = scancomplete(ks) && state > length(ks.items)
length{T<:ScanIterator}(ks::T) = length(ks.items)
scancomplete{T<:ScanIterator}(ks::T) = ks.cursor == "0" && ks.hascanned

"""retrieve the scan's results array"""
results{T<:ScanIterator}(ks::T) = ks.items

"""not implemented since `collect` would block the server"""
Base.collect{T<:ScanIterator}(ks::T) = warn("blocking operation not implemented")

type AllKeyScanner <: ScanIterator
    conn::RedisConnection
    cursor::String
    match::String           # key pattern
    count::Int              # upper bound number of items to retrieve
    items::Array{String, 1} # results of scan
    hascanned::Bool         # has the scan method been called at least once
    AllKeyScanner(conn, match, count) =
        new(conn, "0", match, count, Array{String, 1}(0), false)
end
function show(io::IO, ks::AllKeyScanner)
    println(io, "AllKeyScanner")
    println(io, "    match: ", ks.match)
    println(io, "    count: ", ks.count)
    println(io, "retrieved: ", length(ks))
    println(io, " complete: ", scancomplete(ks))
end

allkeyscanner(conn, match, count=10) = AllKeyScanner(conn, match, count)

function allkeyscandefault(ks::AllKeyScanner)
    sresult = scan(ks.conn, ks.cursor, "MATCH", ks.match, "COUNT", ks.count)
    ks.hascanned = true
    ks.cursor = sresult[1]
    if length(sresult) > 1
        @inbounds for i in 2:length(sresult)
            push!(ks.items, sresult[i])
        end
    end
end

function next(ks::AllKeyScanner, state)
    !scancomplete(ks) && allkeyscandefault(ks)
    ks.items[state], state+1
end

"""
TODO:  as per https://redis.io/commands/scan#return-value both ZSCAN and HSCAN
return a 2 element multi bulk array, first element is cursor, 2nd is an array
of scores and members for ZSCAN, and an array of field names and values for HSCAN.
We could return `Tuple`s for ZSCAN and `Dict`s for HSCAN.
"""
type KeyScanner <: ScanIterator
    conn::RedisConnection
    key::String
    cursor::String
    match::String           # key pattern
    count::Int              # upper bound number of items to retrieve
    items::Array{String, 1} # results of scan
    hascanned::Bool         # has the scan method been called at least once
    redis_scan_fn::Function
    function KeyScanner(conn, key, match, count)
        ktype = keytype(conn, key)
        if !contains(==, ["set", "zset", "hash"], ktype)
            throw(ProtocolException("Wrong key type: expected Set, ZSet, or Hash;
                    received $ktype"))
        end
        if ktype == "set"
            scan_fn = sscan
        elseif ktype == "zset"
            scan_fn = zscan
        else
            scan_fn = hscan
        end

        new(conn, key, "0", match, count, Array{String, 1}(0), false, scan_fn)
    end
end

function show(io::IO, ks::KeyScanner)
    println(io, "KeyScanner")
    println(io, "      key: ", ks.key)
    println(io, "    match: ", ks.match)
    println(io, "    count: ", ks.count)
    println(io, "retrieved: ", length(ks))
    println(io, " complete: ", scancomplete(ks))
end

keyscanner(conn, key, match, count=10) = KeyScanner(conn, key, match, count)

function keyscandefault(ks::KeyScanner)
    sresult = ks.redis_scan_fn(ks.conn, ks.key, ks.cursor, "MATCH", ks.match, "COUNT", ks.count)
    ks.hascanned = true
    ks.cursor = sresult[1]
    if length(sresult) > 1
        @inbounds for i in 2:length(sresult)
            push!(ks.items, sresult[i])
        end
    end
end

function next(ks::KeyScanner, state)
    !scancomplete(ks) && keyscandefault(ks)
    ks.items[state], state+1
end
