conn = RedisConnection()

flushall(conn)

# some random key names
    testkey = "Redis_Test_"*randstring()
    testkey2 = "Redis_Test_"*randstring()
    testkey3 = "Redis_Test_"*randstring()
    testkey4 = "Redis_Test_"*randstring()
    testhash = "Redis_Test_"*randstring()

# some random strings
s1 = randstring(); s2 = randstring(); s3 = randstring()
s4 = randstring(); s5 = randstring(); s6 = randstring()
s7 = randstring(); s8 = randstring(); s9 = randstring()

# constants for code legibility
const REDIS_PERSISTENT_KEY =  -1
const REDIS_EXPIRED_KEY =  -2

@testset "Strings" begin
    @test set(conn, testkey, s1) == "OK"
    @test get(conn, testkey) == Nullable(s1)
    @test Redis.exists(conn, testkey)
    @test keys(conn, testkey) == Set([testkey])
    @test del(conn, testkey, "notakey", "notakey2") == 1  # only 1 of 3 key exists

    # 'NIL'
    @test isnull(get(conn, "notakey"))

    set(conn, testkey, s1)
    set(conn, testkey2, s2)
    set(conn, testkey3, s3)
    # RANDOMKEY can return 'NIL', so it returns Nullable.  KEYS * always returns empty Set when Redis is empty
    @test get(randomkey(conn)) in keys(conn, "*")
    @test getrange(conn, testkey, 0, 3) == s1[1:4]

    set(conn, testkey, 2)
    @test incr(conn, testkey) == 3
    @test incrby(conn, testkey, 3) == 6
    @test incrbyfloat(conn, testkey, 1.5) == "7.5"
    @test mget(conn, testkey, testkey2, testkey3) == [Nullable("7.5"), Nullable(s2), Nullable(s3)]
    @test strlen(conn, testkey2) == length(s2)
    @test Redis.rename(conn, testkey2, testkey4) == "OK"
    @test testkey4 in keys(conn,"*")
    del(conn, testkey, testkey2, testkey3, testkey4)

    @test append(conn, testkey, s1) == length(s1)
    @test append(conn, testkey, s2) == length(s1) + length(s2)
    get(conn, testkey) == string(s1, s2)
    del(conn, testkey)
end

@testset "Bits" begin
    @test setbit(conn,testkey, 0, 1) == 0
    @test setbit(conn,testkey, 2, 1) == 0
    @test getbit(conn, testkey, 0) == 1
    @test getbit(conn, testkey, 1) == 0  # default is 0
    @test getbit(conn, testkey, 2) == 1
    @test bitcount(conn, testkey) == 2
    del(conn, testkey)

    for i=0:3
        setbit(conn, testkey, i, 1)
        setbit(conn, testkey2, i, 1)
    end
    @test bitop(conn, "AND", testkey3, testkey, testkey2) == 1

    for i=0:3
        setbit(conn, testkey, i, 1)
        setbit(conn, testkey2, i, 0)
    end
    bitop(conn, "AND", testkey3, testkey, testkey2)
    @test [getbit(conn, testkey3, i) for i in 0:3] == zeros(4)

    @test bitop(conn, "OR", testkey3, testkey, testkey2) == 1
    @test [getbit(conn, testkey3, i) for i in 0:3] == ones(4)

    setbit(conn, testkey, 0, 0)
    setbit(conn, testkey, 1, 0)
    setbit(conn, testkey2, 1, 1)
    setbit(conn, testkey2, 3, 1)
    @test bitop(conn, "XOR", testkey3, testkey, testkey2) == 1
    @test [getbit(conn, testkey3, i) for i in 0:3] == [0; 1; 1; 0]

    @test bitop(conn, "NOT", testkey3, testkey3) == 1
    @test [getbit(conn, testkey3, i) for i in 0:3] == [1; 0; 0; 1]
    del(conn, testkey, testkey2, testkey3)
end

@testset "Dump" begin
    # TODO: DUMP AND RESTORE HAVE ISSUES
    #=
    set(conn, testkey, "10")
    # this line passes test when a client is available:
    @test [UInt8(x) for x in Redis.dump(r, testkey)] == readbytes(`redis-cli dump t`)[1:end-1]
    =#

    #= this causes 'ERR DUMP payload version or checksum are wrong', a TODO:  need to
    translate the return value and send it back correctly
    set(conn, testkey, 1)
    redisdump = Redis.dump(conn, testkey)
    del(conn, testkey)
    restore(conn, testkey, 0, redisdump)
    =#
end

@testset "Migrate" begin
    # TODO: test of `migrate` requires 2 server instances in Travis
    set(conn, testkey, s1)
    @test move(conn, testkey, 1)
    @test Redis.exists(conn, testkey) == false
    @test Redis.select(conn, 1) == "OK"
    @test get(conn, testkey) == Nullable(s1)
    del(conn, testkey)
    Redis.select(conn, 0)
end

@testset "Expiry" begin
    set(conn, testkey, s1)
    expire(conn, testkey, 1)
    sleep(1)
    @test Redis.exists(conn, testkey) == false

    set(conn, testkey, s1)
    expireat(conn, testkey,  round(Int, Dates.datetime2unix(time(conn)+Dates.Second(1))))
    sleep(2) # only passes test with 2 second delay
    @test Redis.exists(conn, testkey) == false

    set(conn, testkey, s1)
    @test pexpire(conn, testkey, 1)
    @test ttl(conn, testkey) == REDIS_EXPIRED_KEY

    set(conn, testkey, s1)
    @test pexpire(conn, testkey, 2000)
    @test pttl(conn, testkey) > 100
    @test persist(conn, testkey)
    @test ttl(conn, testkey) == REDIS_PERSISTENT_KEY
    del(conn, testkey, testkey2, testkey3)
end

@testset "Lists" begin
    @test lpush(conn, testkey, s1, s2, "a", "a", s3, s4) == 6
    @test lpop(conn, testkey) == Nullable(s4)
    @test rpop(conn, testkey) == Nullable(s1)
    @test isnull(lpop(conn, "non_existent_list"))
    @test isnull(rpop(conn, "non_existent_list"))
    @test llen(conn, testkey) == 4
    @test isnull(lindex(conn, "non_existent_list", 1))
    @test lindex(conn, testkey, 0) == Nullable(s3)
    @test isnull(lindex(conn, testkey, 10))
    @test lrem(conn, testkey, 0, "a") == 2
    @test lset(conn, testkey, 0, s5) == "OK"
    @test lindex(conn, testkey, 0) == Nullable(s5)
    @test linsert(conn, testkey, "BEFORE", s2, s3) == 3
    @test linsert(conn, testkey, "AFTER", s3, s6) == 4
    @test lpushx(conn, testkey2, "nothing")  == false
    @test rpushx(conn, testkey2, "nothing")  == false
    @test ltrim(conn, testkey, 0, 1) == "OK"
    @test lrange(conn, testkey, 0, -1) == [s5; s3]
    @test brpop(conn, testkey, 0) == [testkey, s3]
    lpush(conn, testkey, s3)
    @test blpop(conn, testkey, 0) == [testkey, s3]
    lpush(conn, testkey, s4)
    lpush(conn, testkey, s3)
    listvals = [s3; s4; s5]
    for i in 1:3
        @test rpoplpush(conn, testkey, testkey2) == Nullable(listvals[4-i])  # rpop
    end
    @test isnull(rpoplpush(conn, testkey, testkey2))
    @test llen(conn, testkey) == 0
    @test llen(conn, testkey2) == 3
    @test lrange(conn, testkey2, 0, -1) == listvals
    for i in 1:3
        @test brpoplpush(conn, testkey2, testkey, 0) == listvals[4-i]  # rpop
    end
    @test lrange(conn, testkey, 0, -1) == listvals

    # the following command can only be applied to lists containing numeric values
    sortablelist = [pi, 1, 2]
    lpush(conn, testkey3, sortablelist)
    @test Redis.sort(conn, testkey3) == ["1.0", "2.0", "3.141592653589793"]
    del(conn, testkey, testkey2, testkey3)
end

@testset "Hashes" begin
    @test hmset(conn, testhash, Dict(1 => 2, "3" => 4, "5" => "6")) == "OK"
    @test hexists(conn, testhash, 1) == true
    @test hexists(conn, testhash, "1") == true
    @test hget(conn, testhash, 1) == Nullable("2")
    @test hgetall(conn, testhash) == Dict("1" => "2", "3" => "4", "5" => "6")

    @test isnull(hget(conn, testhash, "non_existent_field"))
    @test hmget(conn, testhash, 1, 3) == [Nullable("2"), Nullable("4")]
    # this is the one edge case where we can get a mixture of nils and strings in same array
    a = hmget(conn, testhash, "non_existent_field1", "non_existent_field2")
    @test isnull(a[1])
    @test isnull(a[2])

    @test Set(hvals(conn, testhash)) == Set(["2", "4", "6"]) # use Set for comp as hash ordering is random
    @test Set(hkeys(conn, testhash)) == Set(["1", "3", "5"])
    @test hset(conn, testhash, "3", 10) == false # if the field already hset returns false
    @test hget(conn, testhash, "3") == Nullable("10") # but still sets it to the new value
    @test hset(conn, testhash, "10", "10") == true # new field hset returns true
    @test hget(conn, testhash, "10") == Nullable("10") # correctly set new field
    @test hsetnx(conn, testhash, "1", "10") == false # field exists
    @test hsetnx(conn, testhash, "11", "10") == true # field doesn't exist
    @test hlen(conn, testhash) == 5  # testhash now has 5 fields

    @test hincrby(conn, testhash, "1", 1) == 3
    @test float(hincrbyfloat(conn, testhash, "1", 1.5)) == 4.5

    del(conn, testhash)
end

@testset "Sets" begin
    @test sadd(conn, testkey, s1) == true
    @test sadd(conn, testkey, s1) == false  # already exists
    @test sadd(conn, testkey, s2) == true
    @test smembers(conn, testkey) == Set([s1, s2])
    @test scard(conn, testkey) == 2
    sadd(conn, testkey, s3)
    @test smove(conn, testkey, testkey2, s3) == true
    @test sismember(conn, testkey2, s3) == true
    sadd(conn, testkey2, s2)
    @test sunion(conn, testkey, testkey2) == Set([s1, s2, s3])
    @test sunionstore(conn, testkey3, testkey, testkey2) == 3
    @test srem(conn, testkey3, s1, s2, s3) == 3
    @test smembers(conn, testkey3) == Set([])
    @test sinterstore(conn, testkey3, testkey, testkey2) == 1
    # only the following method returns 'nil' if the Set does not exist
    @test srandmember(conn, testkey3) in Set([Nullable(s1), Nullable(s2), Nullable(s3)])
    @test isnull(srandmember(conn, "empty_set"))
    # this method returns an emtpty Set if the the Set is empty
    @test issubset(srandmember(conn, testkey2, 2), Set([s1, s2, s3]))
    @test srandmember(conn, "non_existent_set", 10) == Set{AbstractString}()
    @test sdiff(conn, testkey, testkey2) == Set([s1])
    @test spop(conn, testkey) in Set([Nullable(s1), Nullable(s2), Nullable(s3)])
    @test isnull(spop(conn, "empty_set"))
    del(conn, testkey, testkey2, testkey3)
end

@testset "Sorted Sets" begin
    @test zadd(conn, testkey, 0, "a") == true
    @test zadd(conn, testkey, 1., "a") == false
    @test zadd(conn, testkey, 1., "b") == true
    @test zrange(conn, testkey, 0, -1) == AbstractString["a", "b"]
    @test zcard(conn, testkey) == 2
    zadd(conn, testkey, 1.5, "c")
    @test zcount(conn, testkey, 0, 1) == 2   # range as int
    @test zcount(conn, testkey, "-inf", "+inf") == 3 # range as string
    @test zincrby(conn, testkey, 1, "a") == "2"
    @test float(zincrby(conn, testkey, 1.2, "a")) == 3.2
    @test zrem(conn, testkey, "a", "b") == 2
    del(conn, testkey)

    @test zadd(conn, testkey, zip(zeros(1:3), ["a", "b", "c"])...) == 3
    del(conn, testkey)

    vals = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]

    # tests where all scores == 0
    zadd(conn, testkey, zip(zeros(length(vals)), vals)...)
    @test zlexcount(conn, testkey, "-", "+") == length(vals)
    @test zlexcount(conn, testkey, "[b", "[f") == 5
    @test zrangebylex(conn, testkey, "-", "[c") == AbstractString["a", "b", "c"]
    @test zrangebylex(conn, testkey, "[aa", "(g") == AbstractString["b", "c", "d", "e", "f"]
    @test zrangebylex(conn, testkey, "[a", "(g") == AbstractString["a", "b", "c", "d", "e", "f"]
    @test zremrangebylex(conn, testkey, "[a", "[h") == 8
    @test zrange(conn, testkey, 0, -1) == AbstractString["i", "j"]
    del(conn, testkey)

    # tests where scores are sequence 1:10
    zadd(conn, testkey, zip(1:length(vals), vals)...)
    @test zrangebyscore(conn, testkey, "(1", "2") == AbstractString["b"]
    @test zrangebyscore(conn, testkey, "1", "2") == AbstractString["a", "b"]
    @test zrangebyscore(conn, testkey, "(1", "(2") == []
    @test zrank(conn, testkey, "d") == Nullable(3) # redis arrays 0-base

    # 'NIL'
    @test isnull(zrank(conn, testkey, "z"))
    del(conn, testkey)

    zadd(conn, testkey, zip(1:length(vals), vals)...)
    @test zremrangebyrank(conn, testkey, 0, 1) == 2
    @test zrange(conn, testkey, 0, -1, "WITHSCORES") == AbstractString["c", "3", "d", "4", "e", "5", "f", "6", "g", "7", "h", "8", "i", "9", "j", "10"]
    @test zremrangebyscore(conn, testkey, "-inf", "(5") == 2
    @test zrange(conn, testkey, 0, -1, "WITHSCORES") == AbstractString["e", "5", "f", "6", "g", "7", "h", "8", "i", "9", "j", "10"]
    @test zrevrange(conn, testkey, 0, -1) == AbstractString["j", "i", "h", "g", "f", "e"]
    @test zrevrangebyscore(conn, testkey, "+inf", "-inf") == AbstractString["j", "i", "h", "g", "f", "e"]
    @test zrevrangebyscore(conn, testkey, "+inf", "-inf", "WITHSCORES", "LIMIT", 2, 3) == AbstractString["h", "8", "g", "7", "f", "6"]
    @test zrevrangebyscore(conn, testkey, 7, 5) == AbstractString["g", "f", "e"]
    @test zrevrangebyscore(conn, testkey, "(6", "(5") == AbstractString[]
    @test zrevrank(conn, testkey, "e") == Nullable(5)
    @test isnull(zrevrank(conn, "ordered_set", "non_existent_member"))
    @test Redis.zscore(conn, testkey, "e") == Nullable("5")
    @test isnull(Redis.zscore(conn, "ordered_set", "non_existent_member"))
    del(conn, testkey)

    vals2 = ["a", "b", "c", "d"]
    zadd(conn, testkey, zip(1:length(vals), vals)...)
    zadd(conn, testkey2, zip(1:length(vals2), vals2)...)
    @test zunionstore(conn, testkey3, 2, [testkey, testkey2]) == 10
    @test zrange(conn, testkey3, 0, -1) == AbstractString["a", "b", "e", "c", "f", "g", "d", "h", "i", "j"]
    del(conn, testkey3)
    zunionstore(conn, testkey3, 2, [testkey, testkey2], [2; 3])
    @test zrange(conn, testkey3, 0, -1) == AbstractString["a", "b", "e", "f", "g", "c", "h", "i", "d", "j"]
    zunionstore(conn, testkey3, 2, [testkey, testkey2], [2; 3], aggregate=Aggregate.Max)
    @test zrange(conn, testkey3, 0, -1) == AbstractString["a", "b", "c", "e", "d", "f", "g", "h", "i", "j"]
    zunionstore(conn, testkey3, 2, [testkey, testkey2], [2; 3], aggregate=Aggregate.Min)
    @test zrange(conn, testkey3, 0, -1) == AbstractString["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
    del(conn, testkey3)

    vals2 = ["a", "b", "c", "d"]
    @test zinterstore(conn, testkey3, 2, [testkey, testkey2]) == 4
    del(conn, testkey, testkey2, testkey3)
end

@testset "HyperLogLog" begin
    @test pfadd(conn, "hll", "a", "b", "c", "d", "e", "f", "g") == true
    @test pfcount(conn, "hll") == 7
    pfadd(conn, "hll1", "foo", "bar", "zap", "a")
    pfadd(conn, "hll2", "a", "b", "c", "foo")
    @test pfmerge(conn, "hll3", "hll1", "hll2") == "OK"
    @test pfcount(conn, "hll3") == 6
    del(conn, "hll", "hll1", "hll2", "hll3")
end

@testset "Scan" begin
    @testset "keys" begin
        set(conn, testkey, s1)
        set(conn, testkey2, s2)
        set(conn, testkey3, s3)
        #@test scan(conn, 0) == ("0", Any[testkey, testkey2, testkey3])
        response = scan(conn, 0)
        @test response[1] == "0" # cursor should indicate no more items available
        @test issubset(response[2], Any[testkey, testkey2, testkey3])
        response = scan(conn, 0, "MATCH", testkey[1:3]*"*", "COUNT", 1)
        @test response[1] != "0"    # cursor should indicate more items available
        @test issubset(response[2], Set([testkey, testkey2, testkey3]))
        del(conn, testkey, testkey2, testkey3)
    end
    @testset "sets" begin
        sadd(conn, testkey, Set([s1, s2, s3]))
        @test sscan(conn, testkey, 0) == ('0', Set([s1, s2, s3]))
        del(conn, testkey)
    end
    @testset "ordered sets" begin
        zadd(conn, testkey, (1, s1), (2, s2), (3, s3))
        @test zscan(conn, testkey, 0) == ('0', OrderedSet([s1, "1", s2, "2", s3, "3"]))
        del(conn, testkey)
    end

    @testset "hashes" begin
        hmset(conn, testkey, Dict("f1"=>s1, "f2"=>s2, "f3"=>s3))
        @test hscan(conn, testkey, 0) == ('0', Dict{AbstractString,AbstractString}("f1"=>s1,"f2"=>s2,"f3"=>s3))
        del(conn, testkey)
    end
end

@testset "StreamScan" begin
    @testset "keys" begin
        set(conn, testkey, s1)
        set(conn, testkey2, s2)
        set(conn, testkey3, s3)
        ks = KeyScanner(conn, "*", 1)
        @test issubset(next!(ks), [testkey, testkey2, testkey3])
        @test Set(collect(ks)) == Set([testkey, testkey2, testkey3])
        arr = Vector{AbstractString}()
        collectAsync!(ks, arr)
        sleep(1)
        @test Set(arr) == Set([testkey, testkey2, testkey3])
        del(conn, testkey, testkey2, testkey3)
    end
    @testset "sets" begin
        sadd(conn, testkey, [s1, s2, s3])
        ks = SetScanner(conn, testkey, "*", 1)
        @test issubset(next!(ks), [s1, s2, s3])
        @test Set(collect(ks)) == Set([s1, s2, s3])
        arr = Vector{AbstractString}()
        collectAsync!(ks, arr)
        sleep(1)
        @test Set(arr) == Set([s1, s2, s3])
        del(conn, testkey)
    end
    @testset "ordered sets" begin
        zadd(conn, testkey, (1., s1), (2., s2), (3., s3))
        ks = OrderedSetScanner(conn, testkey, "*", 1)
        @test issubset(next!(ks), [(1., s1), (2., s2), (3., s3)])
        @test collect(ks) == [(1., s1), (2., s2), (3., s3)]
        arr = Vector{Tuple{Float64, AbstractString}}()
        collectAsync!(ks, arr)
        sleep(1)
        @test arr == [(1., s1), (2., s2), (3., s3)]
        del(conn, testkey)
    end
    @testset "hashes" begin
        dict = Dict("f1"=>s1, "f2"=>s2, "f3"=>s3)
        hmset(conn, testkey, dict)
        ks = HashScanner(conn, testkey, "*", 1)
        @test issubset(Set(next!(ks)), Set(dict))
        @test collect(ks) == dict
        dict2 = Dict{AbstractString, AbstractString}()
        collectAsync!(ks, dict2)
        sleep(1)
        @test dict2 == dict
        del(conn, testkey)
    end
end

@testset "Scripting" begin
    script = "return {KEYS[1], KEYS[2], ARGV[1], ARGV[2]}"
    args = ["key1", "key2", "first", "second"]
    resp = evalscript(conn, script, 2, args)
    @test resp == args
    del(conn, "key1")

    script = "return redis.call('set', KEYS[1], 'bar')"
    ky = "foo"
    resp = evalscript(conn, script, 1, [ky])
    @test resp == "OK"
    del(conn, ky)

    script = "return {'1','2',{'3','Hello World!', {'4', 'inner'}}}"
    # TODO: This should return nested arrays and not tuple
    #@test_skip evalscript(conn, script) == (["1", "2"], ["3", "Hello World!"])

# NOTE the truncated float, and truncated array in the response
# as per http://redis.io/commands/eval
#       Lua has a single numerical type, Lua numbers. There is
#       no distinction between integers and floats. So we always
#       convert Lua numbers into integer replies, removing the
#       decimal part of the number if any. If you want to return
#       a float from Lua you should return it as a string, exactly
#       like Redis itself does (see for instance the ZSCORE command).
#
#       There is no simple way to have nils inside Lua arrays,
#       this is a result of Lua table semantics, so when Redis
#       converts a Lua array into Redis protocol the conversion
#       is stopped if a nil is encountered.
#@test evalscript(conn, "return {1, 2, 3.3333, 'foo', nil, 'bar'}",  0, []) == [1, 2, 3, "foo"]
end

# @testset "Transactions" begin
#     trans = open_transaction(conn)
#     @test set(trans, testkey, "foobar") == "QUEUED"
#     @test get(trans, testkey) == "QUEUED"
#     @test exec(trans) == ["OK", "foobar"]
#     @test del(trans, testkey) == "QUEUED"
#     @test exec(trans) == [true]
#     disconnect(trans)
# end

@testset "Pipelines" begin
    pipe = open_pipeline(conn)
    set(pipe, testkey3, "anything")
    @test length(read_pipeline(pipe)) == 1
    get(pipe, testkey3)
    set(pipe, testkey4, "testing")
    result = read_pipeline(pipe)
    @test length(result) == 2
    @test result == ["anything", "OK"]
    @test del(pipe, testkey3) == 1
    @test del(pipe, testkey4) == 2
    @test result ==  ["anything", "OK"]
    disconnect(pipe)
end

function pubSubTest(conn)
      g(y) = print(y)
      x = String[]
      f(y) = begin push!(x, y); println("channel func f: ", y) end
      h(y) = begin push!(x, y); println("channel func h: ", y) end
      subs = SubscriptionConnection(parent=conn)
      subscribe(subs, "channel", f)
      subscribe(subs, "duplicate", h)
      subs, x
end   

@testset "Pub/Sub" begin
    subs, x = pubSubTest(conn)
    clients = client_list(subs.parent)
    @test length(clients) == 2
    # one client should have 2 subscriptions  
    @test (clients[1]["sub"] == "2" || clients[2]["sub"] == "2")
    # @test pubsub(conn, "channels") = Any["duplicate", "channel"] fails, ""channels"" is not a valid function argument name
    @test pubsub(conn, "numsub", "duplicate", "channel") == Any["duplicate", 1, "channel", 1]
    tsk = startSubscriptionLoopAsync(subs, println)
    @test typeof(tsk) == Task
    @test tsk.state == :queued || tsk.state == :runnable
    @test publish(subs.parent, "channel", "hello, world!") == 1
    sleep(1)
    @test x == ["hello, world!"]
    unsubscribe(subs, "channel")
    unsubscribe(subs, "duplicate")
    disconnect(subs)
end

# some tests removed, were causing travis failure
@testset "Sundry" begin
    #@test bgrewriteaof(conn) == "Background append only file rewriting started"
    #sleep(3)
    #@test bgsave(conn) == "Background saving started"
    @test typeof(command(conn)) == Array{Any, 1}
    @test typeof(dbsize(conn)) == Int64
    @test Redis.echo(conn, "astringtoecho") == "astringtoecho"
    @test Redis.ping(conn) == "PONG"
    @test flushall(conn) == "OK"
    @test flushdb(conn) == "OK"
    redisinfo = split(Redis.info(conn), "\r\n")
    # select a few items that should appear in result
    @test issubset(["# Server", "# CPU", "# Cluster", "# Keyspace"], redisinfo)
    redisinfo = split(Redis.info(conn, "memory"), "\r\n")
    # select a few items that should appear in result
    @test issubset(["# Memory"], redisinfo)
    @test typeof(Dates.unix2datetime(lastsave(conn))) == DateTime
    @test role(conn)  == ["master", 0, Any[]]
    #@test Redis.save(conn) == "OK"
    @test Redis.slaveof(conn, "localhost", 6379) == "OK"
    @test slaveof(conn, "no", "one") == "OK"
    @test client_setname(conn, "aClientName") == "OK"
    @test client_getname(conn) == "aClientName"
    @test typeof(Redis.time(conn)) == DateTime 
    begin 
        tic()
        client_pause(conn, 2000)
        client_getname(conn) == "aClientName"
        @test toc() > 2
    end
    

end

disconnect(conn)
