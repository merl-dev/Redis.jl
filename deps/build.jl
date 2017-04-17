using BinDeps
using Compat

@BinDeps.setup

libhiredis = library_dependency("libhiredis")

provides(AptGet, Dict("libhiredis-dev"=>libhiredis))

@BinDeps.install Dict(:libhiredis => :libhiredis)
