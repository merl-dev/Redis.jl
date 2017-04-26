struct ClusterNode{T<:AbstractString}
    id::T
    ipport::T
    flags::Array{T, 1}
    master::T
    pingsent::Int
    pongrecv::Int
    confepoch::Int
    linkstate::T
    slots::Array{UnitRange, 1}
end

function Base.show(io::IO, node::ClusterNode)
    println(io, "Cluster Node $(node.flags)")
    println(io, "          id => ", node.id)
    println(io, "     ip:port => ", node.ipport)
    println(io, "      master => ", node.master)
    println(io, "   ping sent => ", node.pingsent)
    println(io, "   ping recv => ", node.pongrecv)
    println(io, "config epoch => ", node.confepoch)
    println(io, "  link state => ", node.linkstate)
    println(io, "       slots => ", node.slots)
end

function ClusterNode(line::AbstractString)
    splits = split(line, ' ')
    flags = split(splits[3], ',')
    slotstrings = splits[9:end]
    slotarray = UnitRange[]
    for slot in slotstrings
        slots = split(slot, "-")
        if length(slots) == 1
            s = parse(Int, slots[1])
            push!(slotarray, UnitRange(s,s))
        else
            push!(slotarray, UnitRange(parse(Int, slots[1]), parse(Int, slots[2])))
        end
    end
    ClusterNode(splits[1], splits[2], flags, splits[4], parse(Int, splits[5]),
            parse(Int, splits[6]), parse(Int, splits[7]), splits[8], slotarray)
end
