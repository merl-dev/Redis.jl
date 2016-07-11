Some simple benchmarking results that demonstrate performance enhancements made by refactoring and switching to libhiredis.

## minor adjustment to parser -- this is redundant

parser.jl: `parse_bulk_string(s::TCPSocket, len::Int)`

__original: `join(map(Char,b[1:end-2]))`__

```
@benchmark lrange(conn, "nl", 0, -1)

BenchmarkTools.Trial:
samples:          10000
evals/sample:     1
time tolerance:   5.00%
memory tolerance: 1.00%
memory estimate:  106.00 kb
allocs estimate:  2055
minimum time:     189.97 μs (0.00% GC)
median time:      202.62 μs (0.00% GC)
mean time:        216.26 μs (5.69% GC)
maximum time:     4.15 ms (0.00% GC)
```

__new: `bytestring(s)[1:end-2]`__

```
@benchmark lrange(conn, "nl", 0, -1)`
BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  84.13 kb
  allocs estimate:  1655
  minimum time:     141.43 μs (0.00% GC)
  median time:      152.76 μs (0.00% GC)
  mean time:        163.96 μs (5.99% GC)
  maximum time:     2.93 ms (94.36% GC)
```

__HiRedis__

```
@benchmark HiRedis.do_command("LRANGE nl 0 -1")`
BenchmarkTools.Trial:
 samples:          10000
 evals/sample:     1
 time tolerance:   5.00%
 memory tolerance: 1.00%
 memory estimate:  18.02 kb
 allocs estimate:  310
 minimum time:     73.83 μs (0.00% GC)
 median time:      80.80 μs (0.00% GC)
 mean time:        82.93 μs (2.16% GC)
 maximum time:     2.68 ms (96.56% GC)
```

#########################################################

## moving to libhiredis after latest merge

#### list with 100 3-byte items

__without libhiredis__

```
@benchmark lrange(conn, "nl2", 0, -1)`
BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  78.06 kb
  allocs estimate:  1449
  minimum time:     138.89 μs (0.00% GC)
  median time:      149.77 μs (0.00% GC)
  mean time:        159.82 μs (5.76% GC)
  maximum time:     3.02 ms (94.64% GC)
```

__with libhiredis, not optimized yet__

```
@benchmark lrange(conn, "nl2", 0, -1)`
BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  13.41 kb
  allocs estimate:  267
  minimum time:     92.50 μs (0.00% GC)
  median time:      100.65 μs (0.00% GC)
  mean time:        102.82 μs (1.72% GC)
  maximum time:     3.14 ms (95.06% GC)
```

__HiRedis__

```
@benchmark do_command("lrange nl2 0 -1")`
BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  10.33 kb
  allocs estimate:  203
  minimum time:     72.94 μs (0.00% GC)
  median time:      78.81 μs (0.00% GC)
  mean time:        80.44 μs (1.24% GC)
  maximum time:     2.75 ms (96.45% GC)
```

#### list with 600 3-byte items

__without libhiredis__

```
@benchmark lrange(conn, "nl2", 0, -1)
BenchmarkTools.Trial:
  samples:          9897
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  439.80 kb
  allocs estimate:  7952
  minimum time:     428.53 μs (0.00% GC)
  median time:      446.63 μs (0.00% GC)
  mean time:        501.52 μs (10.44% GC)
  maximum time:     3.62 ms (83.03% GC)
```

__with libhiredis, not optimized yet__

```
@benchmark lrange(conn, "nl2", 0, -1)
BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  65.58 kb
  allocs estimate:  1357
  minimum time:     240.78 μs (0.00% GC)
  median time:      254.41 μs (0.00% GC)
  mean time:        263.25 μs (2.89% GC)
  maximum time:     3.00 ms (90.24% GC)
```

__HiRedis__

```
@benchmark do_command("lrange nl2 0 -1")
BenchmarkTools.Trial:
  samples:          10000
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  62.50 kb
  allocs estimate:  1293
  minimum time:     220.10 μs (0.00% GC)
  median time:      230.33 μs (0.00% GC)
  mean time:        238.20 μs (2.86% GC)
  maximum time:     2.74 ms (90.23% GC)
```

#######################################

## Pipeline test

set key 10^6 times and read reply

```
function pipeTest()
    for i=1:1000000
      set(pipe, "newkey", "abc")
    end
    result = read_pipeline(pipe)
end
```

__without libhiredis__

```
@benchmark pipeTest()
BenchmarkTools.Trial:
  samples:          1
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  4.39 gb
  allocs estimate:  99998018
  minimum time:     38.43 s (2.78% GC)
  median time:      38.43 s (2.78% GC)
  mean time:        38.43 s (2.78% GC)
  maximum time:     38.43 s (2.78% GC)
```
__performance ==> 26K writes per second__

__with libhiredis__

```
```

__HiRedis__

```
function pipeTest()
    for i=1:1000000
       kvset("newkey", "abc", pipeline=true)
    end
    result = get_reply()
end
```

```
@benchmark pipeTest()
BenchmarkTools.Trial:
  samples:          3
  evals/sample:     1
  time tolerance:   5.00%
  memory tolerance: 1.00%
  memory estimate:  237.87 mb
  allocs estimate:  5998998
  minimum time:     2.46 s (2.20% GC)
  median time:      2.46 s (2.52% GC)
  mean time:        2.46 s (2.46% GC)
  maximum time:     2.46 s (2.67% GC)
```
__performance ==> 406K writes per second__
