######## Reply Type Conversions #########

convert_response(::Type{Float64}, response) = float(response)::Float64
convert_response(::Type{Bool}, response::Integer) = response == 1 ? true : false
convert_response(::Type{Set{AbstractString}}, response) = Set{AbstractString}(response)
convert_response(::Type{OrderedSet{AbstractString}}, response) = OrderedSet{AbstractString}(response)
convert_response(::Type{Array{Any,1}}, response) = response

function convert_response(::Type{Dict{AbstractString, AbstractString}}, response)
    iseven(length(response)) || throw(ClientException("Response could not be converted to Dict"))
    retdict = Dict{AbstractString, AbstractString}()
    for i=1:2:length(response)
        retdict[response[i]] = response[i+1]
    end
    retdict
end

function convert_eval_response(::Any, response)
    if response == nothing
        Nullable()
    else
        response
    end
end

import Base: ==
=={T<:AbstractString, U<:AbstractString}(A::Nullable{T}, B::Nullable{U}) = get(A) == get(B)
=={T<:Number, U<:Number}(A::Nullable{T}, B::Nullable{U}) = get(A) == get(B)

convert_response(::Type{AbstractString}, response) = string(response)
convert_response(::Type{Integer}, response) = response

function convert_response(::Type{Array{AbstractString, 1}}, response)
    r = Array{AbstractString, 1}()
    for item in response
        push!(r, item)
    end
    r
end

function convert_response{T<:Number}(::Type{Nullable{T}}, response)
    if response == nothing
       Nullable{T}()
   elseif issubtype(typeof(response), T)
        Nullable{T}(response)
    else
       response
    end
end

function convert_response{T<:AbstractString}(::Type{Nullable{T}}, response)
    if response == nothing
       Nullable{T}()
    else
       Nullable{T}(response)
    end
end

# redundant
function convert_response{T<:Number}(::Type{Array{Nullable{T}, 1}}, response)
    if response == nothing
        Array{Nullable{T}, 1}()
   else
        r = Array{Nullable{T},1}()
        for item in response
            push!(r, tryparse(T, item))
        end
        r
    end
end

function convert_response{T<:AbstractString}(::Type{Array{Nullable{T}, 1}}, response)
    if response == nothing
        Array{Nullable{T}, 1}()
   else
        r = Array{Nullable{T},1}()
        for item in response
            push!(r, Nullable{T}(item))
        end
        r
    end
end

function convert_response{T}(::Type{Tuple{AbstractString, T}}, response)
    length(response) == 2 ? (response[1][1], convert_response(T, response[2])) : response[1][1]
end
