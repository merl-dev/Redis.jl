# TODO: create TestSet type to pre and post each test set
using Redis, NullableArrays, Base.Dates, Base.Test

conn = RedisConnection()

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
const REDIS_PERSISTENT_KEY =  -1
const REDIS_EXPIRED_KEY =  -2

@testset "Strings" begin
    flushall(conn)
    @test set(conn, testkey, s1) == "OK"
    @test isequal(get(conn, testkey), Nullable(s1))
    @test Redis.exists(conn, testkey) == 1
    @test isa(keys(conn, testkey), Array{String,1})
    @test isequal(keys(conn, testkey)[1], testkey)
    @test del(conn, testkey, "notakey", "notakey2") == 1
    set(conn, testkey, s1)
    set(conn, testkey2, s2)
    @test unlink(conn, testkey, testkey2) == 2
    @test isnull(get(conn, "notakey"))
    set(conn, testkey, s1)
    @test contains(isequal, keys(conn, "*"), get(randomkey(conn)))
    @test isequal(getrange(conn, testkey, 0, 3), Nullable(s1[1:4]))
    set(conn, testkey, 2)
    @test incr(conn, testkey) == 3
    @test incrby(conn, testkey, 3) == 6
    @test isequal(incrbyfloat(conn, testkey, 1.5), Nullable("7.5"))
    set(conn, testkey2, s2)
    set(conn, testkey3, s3)
    @test isequal(Array(mget(conn, testkey, testkey2, testkey3)), ["7.5", s2, s3])
    @test strlen(conn, testkey2) == length(s2)
    @test Redis.rename(conn, testkey2, testkey4) == "OK"
    @test contains(==, Array(keys(conn,"*")), testkey4)
    del(conn, testkey, testkey2, testkey3, testkey4)
    @test append(conn, testkey, s1) == length(s1)
    @test append(conn, testkey, s2) == length(s1) + length(s2)
    get(conn, testkey) == string(s1, s2)
end

@testset "Bits" begin
    flushall(conn)
    @test setbit(conn,testkey, 0, 1) == 0
    @test setbit(conn,testkey, 2, 1) == 0
    @test getbit(conn, testkey, 0) == 1
    @test getbit(conn, testkey, 1) == 0
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
end

@testset "Dump" begin
    flushall(conn)
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
    flushall(conn)
    set(conn, testkey, s1)
    @test move(conn, testkey, 1) == 1
    @test Redis.exists(conn, testkey) == false
    @test Redis.select(conn, 1) == "OK"
    @test isequal(get(conn, testkey), Nullable{String}(s1))
    Redis.select(conn, 0);
end

@testset "Expiry" begin
    flushall(conn)
    set(conn, testkey, s1)
    expire(conn, testkey, 1)
    sleep(1)
    @test Redis.exists(conn, testkey) == false
    set(conn, testkey, s1)
    current_srv_time_secs = parse(Array(time(conn))[1])
    expireat(conn, testkey,  current_srv_time_secs + 1)
    sleep(1)
    @test Redis.exists(conn, testkey) == false
    set(conn, testkey, s1)
    @test pexpire(conn, testkey, 1) == 1
    @test ttl(conn, testkey) == REDIS_EXPIRED_KEY
    set(conn, testkey, s1)
    @test pexpire(conn, testkey, 2000) == 1
    @test pttl(conn, testkey) > 100
    @test persist(conn, testkey) == 1
    @test ttl(conn, testkey) == REDIS_PERSISTENT_KEY
end

@testset "Lists" begin
    flushall(conn)
    @test lpush(conn, testkey, s1, s2, "a", "a", s3, s4) == 6
    @test isequal(lpop(conn, testkey), Nullable(s4))
    @test isequal(rpop(conn, testkey), Nullable(s1))
    @test isnull(lpop(conn, "non_existent_list"))
    @test isnull(rpop(conn, "non_existent_list"))
    @test llen(conn, testkey) == 4
    @test isnull(lindex(conn, "non_existent_list", 1))
    @test isequal(lindex(conn, testkey, 0), Nullable(s3))
    @test isnull(lindex(conn, testkey, 10))
    @test lrem(conn, testkey, 0, "a") == 2
    @test lset(conn, testkey, 0, s5) == "OK"
    @test isequal(lindex(conn, testkey, 0), Nullable(s5))
    @test linsert(conn, testkey, "BEFORE", s2, s3) == 3
    @test linsert(conn, testkey, "AFTER", s3, s6) == 4
    @test lpushx(conn, testkey2, "nothing")  == false
    @test rpushx(conn, testkey2, "nothing")  == false
    @test ltrim(conn, testkey, 0, 1) == "OK"
    @test Array(lrange(conn, testkey, 0, -1)) == [s5; s3]
    @test Array(brpop(conn, testkey, 0)) == [testkey, s3]
    lpush(conn, testkey, s3)
    @test Array(blpop(conn, testkey, 0)) == [testkey, s3]
    lpush(conn, testkey, s4)
    lpush(conn, testkey, s3)
    listvals = [s3; s4; s5]
    for i in 1:3
        @test isequal(rpoplpush(conn, testkey, testkey2), Nullable(listvals[4-i]))
    end
    @test isnull(rpoplpush(conn, testkey, testkey2))
    @test llen(conn, testkey) == 0
    @test llen(conn, testkey2) == 3
    @test Array(lrange(conn, testkey2, 0, -1)) == listvals
    for i in 1:3
        @test isequal(brpoplpush(conn, testkey2, testkey, 0), Nullable(listvals[4-i]))
    end
    @test Array(lrange(conn, testkey, 0, -1)) == listvals
    # the following command can only be applied to lists containing numeric values
    sortablelist = [pi, 1, 2]
    lpush(conn, testkey3, sortablelist...)
    @test Array(Redis.sort(conn, testkey3)) == ["1.0", "2.0", "3.141592653589793"]
end

@testset "Hashes" begin
    flushall(conn)
    @test hmset(conn, testhash, Dict(1 => 2, "3" => 4, "5" => "6")) == "OK"
    @test hexists(conn, testhash, 1) == true
    @test hexists(conn, testhash, "1") == true
    @test isequal(hget(conn, testhash, 1), Nullable("2"))
    @test Array(hgetall(conn, testhash)) == ["3", "4", "5", "6", "1", "2"]
    @test isnull(hget(conn, testhash, "non_existent_field"))
    @test Array(hmget(conn, testhash, 1, 3)) == ["2", "4"]
    a = hmget(conn, testhash, "non_existent_field1", "non_existent_field2")
    #@test isnull(a[1])
    #@test isnull(a[2])
    @test Array(hvals(conn, testhash)) == ["4", "6", "2"]
    @test Array(hkeys(conn, testhash)) == ["3", "5", "1"]
    @test hset(conn, testhash, "3", 10) == false
    @test isequal(hget(conn, testhash, "3"), Nullable("10"))
    @test hset(conn, testhash, "10", "10") == true
    @test isequal(hget(conn, testhash, "10"), Nullable("10"))
    @test hsetnx(conn, testhash, "1", "10") == false
    @test hsetnx(conn, testhash, "11", "10") == true
    @test hlen(conn, testhash) == 5
    @test hincrby(conn, testhash, "1", 1) == 3
    @test isequal(hincrbyfloat(conn, testhash, "1", 1.5), Nullable("4.5"))
end

@testset "Sets" begin
    flushall(conn)
    @test sadd(conn, testkey, s1) == true
    @test sadd(conn, testkey, s1) == false
    @test sadd(conn, testkey, s2) == true
    @test issubset(Array(smembers(conn, testkey)), [s1, s2]) == true
    @test scard(conn, testkey) == 2
    sadd(conn, testkey, s3)
    @test smove(conn, testkey, testkey2, s3) == true
    @test sismember(conn, testkey2, s3) == true
    sadd(conn, testkey2, s2)
    @test issubset(Array(sunion(conn, testkey, testkey2)), [s3, s1, s2]) == true
    @test sunionstore(conn, testkey3, testkey, testkey2) == 3
    @test srem(conn, testkey3, s1, s2, s3) == 3
    @test smembers(conn, testkey3) == []
    @test sinterstore(conn, testkey3, testkey, testkey2) == 1
    @test contains(==, [s1, s2, s3], get(srandmember(conn, testkey3)))
    @test isnull(srandmember(conn, "empty_set"))
    @test issubset(Array(srandmember(conn, testkey2, 2)), [s1, s2, s3])
    @test srandmember(conn, "non_existent_set", 10) == Any[]
    @test Array(sdiff(conn, testkey, testkey2)) == [s1]
    @test contains(==, [s1, s2, s3], get(spop(conn, testkey)))
    @test isnull(spop(conn, "empty_set"))
end

@testset "Sorted Sets" begin
    flushall(conn)
    @test zadd(conn, testkey, 0, "a") == true
    @test zadd(conn, testkey, 1., "a") == false
    @test zadd(conn, testkey, 1., "b") == true
    @test Array(zrange(conn, testkey, 0, -1)) == String["a", "b"]
    @test zcard(conn, testkey) == 2
    zadd(conn, testkey, 1.5, "c")
    @test zcount(conn, testkey, 0, 1) == 2   # range as int
    @test zcount(conn, testkey, "-inf", "+inf") == 3 # range as string
    @test get(zincrby(conn, testkey, 1, "a")) == "2"
    @test float(get(zincrby(conn, testkey, 1.2, "a"))) == 3.2
    @test zrem(conn, testkey, "a", "b") == 2
    del(conn, testkey)
    @test zadd(conn, testkey, zip(zeros(1:3), ["a", "b", "c"])...) == 3
    del(conn, testkey)
    vals = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
    zadd(conn, testkey, zip(zeros(length(vals)), vals)...)
    @test zlexcount(conn, testkey, "-", "+") == length(vals)
    @test zlexcount(conn, testkey, "[b", "[f") == 5
    @test Array(zrangebylex(conn, testkey, "-", "[c")) == String["a", "b", "c"]
    @test Array(zrangebylex(conn, testkey, "[aa", "(g")) == String["b", "c", "d", "e", "f"]
    @test Array(zrangebylex(conn, testkey, "[a", "(g")) ==
        String["a", "b", "c", "d", "e", "f"]
    @test zremrangebylex(conn, testkey, "[a", "[h") == 8
    @test Array(zrange(conn, testkey, 0, -1)) == String["i", "j"]
    del(conn, testkey)
    zadd(conn, testkey, zip(1:length(vals), vals)...)
    @test Array(zrangebyscore(conn, testkey, "(1", "2")) == String["b"]
    @test Array(zrangebyscore(conn, testkey, "1", "2")) == String["a", "b"]
    @test zrangebyscore(conn, testkey, "(1", "(2") == []
    @test zrank(conn, testkey, "d") == 3
    @test isnull(zrank(conn, testkey, "z"))
    del(conn, testkey)
    zadd(conn, testkey, zip(1:length(vals), vals)...)
    @test zremrangebyrank(conn, testkey, 0, 1) == 2
    @test Array(zrange(conn, testkey, 0, -1, "WITHSCORES")) ==
        String["c", "3", "d", "4", "e", "5", "f", "6", "g", "7", "h", "8", "i", "9", "j", "10"]
    @test zremrangebyscore(conn, testkey, "-inf", "(5") == 2
    @test Array(zrange(conn, testkey, 0, -1, "WITHSCORES")) ==
        String["e", "5", "f", "6", "g", "7", "h", "8", "i", "9", "j", "10"]
    @test Array(zrevrange(conn, testkey, 0, -1)) == String["j", "i", "h", "g", "f", "e"]
    @test Array(zrevrangebyscore(conn, testkey, "+inf", "-inf")) == String["j", "i", "h", "g", "f", "e"]
    @test Array(zrevrangebyscore(conn, testkey, "+inf", "-inf", "WITHSCORES",
        "LIMIT", 2, 3)) == String["h", "8", "g", "7", "f", "6"]
    @test Array(zrevrangebyscore(conn, testkey, 7, 5)) == String["g", "f", "e"]
    @test zrevrangebyscore(conn, testkey, "(6", "(5") == String[]
    @test zrevrank(conn, testkey, "e") == 5
    @test isnull(zrevrank(conn, "ordered_set", "non_existent_member"))
    @test isequal(Redis.zscore(conn, testkey, "e"), Nullable{String}("5"))
    @test isnull(Redis.zscore(conn, "ordered_set", "non_existent_member"))
    del(conn, testkey)
    vals2 = ["a", "b", "c", "d"]
    zadd(conn, testkey, zip(1:length(vals), vals)...)
    zadd(conn, testkey2, zip(1:length(vals2), vals2)...)
    @test zunionstore(conn, testkey3, 2, [testkey, testkey2]) == 10
    @test Array(zrange(conn, testkey3, 0, -1)) ==
        String["a", "b", "e", "c", "f", "g", "d", "h", "i", "j"]
    del(conn, testkey3)
    zunionstore(conn, testkey3, 2, [testkey, testkey2], [2; 3])
    @test Array(zrange(conn, testkey3, 0, -1)) ==
        String["a", "b", "e", "f", "g", "c", "h", "i", "d", "j"]
    zunionstore(conn, testkey3, 2, [testkey, testkey2], [2; 3], aggregate=Aggregate.Max)
    @test Array(zrange(conn, testkey3, 0, -1)) ==
        String["a", "b", "c", "e", "d", "f", "g", "h", "i", "j"]
    zunionstore(conn, testkey3, 2, [testkey, testkey2], [2; 3], aggregate=Aggregate.Min)
    @test Array(zrange(conn, testkey3, 0, -1)) ==
        String["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]
    del(conn, testkey3)
    vals2 = ["a", "b", "c", "d"]
    @test zinterstore(conn, testkey3, 2, [testkey, testkey2]) == 4
end

@testset "HyperLogLog" begin
    flushall(conn)
    @test pfadd(conn, "hll", "a", "b", "c", "d", "e", "f", "g") == true
    @test pfcount(conn, "hll") == 7
    pfadd(conn, "hll1", "foo", "bar", "zap", "a")
    pfadd(conn, "hll2", "a", "b", "c", "foo")
    @test pfmerge(conn, "hll3", "hll1", "hll2") == "OK"
    @test pfcount(conn, "hll3") == 6
end

@testset "Scan" begin
    @testset "keys" begin
        flushall(conn)
        set(conn, testkey, s1)
        set(conn, testkey2, s2)
        set(conn, testkey3, s3)
        response = scan(conn, 0, "MATCH", testkey[1:3]*"*", "COUNT", 10)
        @test response[1] == "0"
        @test contains(==, [testkey, testkey2, testkey3], response[2])
    end
    @testset "sets" begin
        flushall(conn)
        sadd(conn, testkey, s1, s2, s3)
        result = sscan(conn, testkey, 0)
        @test isequal(result[1], "0")
        @test contains(==, [s1, s2, s3], result[2])
    end
    @testset "ordered sets" begin
        flushall(conn)
        zadd(conn, testkey, (1, s1), (2, s2), (3, s3))
        result = zscan(conn, testkey, 0)
        @test isequal(result[1], "0")
        @test Array(result[2:end]) == [s1, "1", s2, "2", s3, "3"]
    end

    @testset "hashes" begin
        flushall(conn)
        hmset(conn, testkey, Dict("f1"=>s1, "f2"=>s2, "f3"=>s3))
        result = hscan(conn, testkey, 0)
        @test isequal(result[1], "0")
        @test Array(result[2:end]) == ["f1", s1, "f2", s2, "f3", s3]
    end
end

@testset "Scan Iterators" begin
    @testset "allkeyscanner" begin
        flushall(conn)
        set(conn, testkey, s1)
        set(conn, testkey2, s2)
        set(conn, testkey3, s3)
        ks = allkeyscanner(conn, "*", 1);
        for akey in ks
            @test contains(==, [testkey, testkey2, testkey3], akey)
        end
    end
    @testset "keyscanner" begin
        flushall(conn)
        sadd(conn, testkey, s1, s2, s3)
        ks = keyscanner(conn, testkey, "*", 10)
        for anitem in ks
            @test contains(==, [s1, s2, s3], anitem)
        end
        del(conn, testkey)
        zadd(conn, testkey, (0, s1), (0, s2), (0, s3))
        ks = keyscanner(conn, testkey, "*", 10)
        for anitem in ks
            @test contains(==, ["0", s1, "0", s2, "0", s3], anitem)
        end
    end
end
@testset "Scripting" begin
    flushall(conn)
    # script = "return {KEYS[1], KEYS[2], ARGV[1], ARGV[2]}"
    # args = ["key1", "key2", "first", "second"]
    # resp = evalscript(conn, script, 2, args, Redis.do_arr_command)
    # @test Array(resp) == args
    # del(conn, "key1")
    #
    # script = "return redis.call('set', KEYS[1], 'bar')"
    # ky = "foo"
    # resp = evalscript(conn, script, 1, [ky])
    # @test resp == "OK"
    # del(conn, ky)
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
#
@testset "multi/exec" begin
    flushall(conn)
    @test_throws MethodError exec(conn)
    trans = TransactionConnection()
    @test multi(trans) == "OK"
    @test set(trans, testkey, s1) == "QUEUED"
    @test get(trans, testkey) == "QUEUED"
    @test zadd(trans, testkey2, 1.0, s2) == "QUEUED"
    @test zscore(trans, testkey2, s2) == "QUEUED"
    @test zscore(trans, "not_such_key", "no_such_member") == "QUEUED"
    resp = exec(trans)
    @test Array(resp[1:4]) == ["OK", s1, 1, "1"]
    @test isnull(resp[5])
    disconnect(trans)
end
#
@testset "Pipeline" begin
    flushall(conn)
    pipe = PipelineConnection()
    set(pipe, testkey, s1)
    get(pipe, testkey)
    zadd(pipe, testkey2, 0, s1)
    zrank(pipe, testkey2, s1)
    zrange(pipe, testkey2, 0, -1)
    @test count(pipe) == 5
    @test read(pipe) == "OK" #set
    @test get(read(pipe)) == s1 #get
    @test read(pipe) == 1 #zadd
    @test read(pipe) == 0  #rank
    @test read(pipe) == [s1]  #zrange
    del(pipe, testkey, testkey2)
    keys(pipe, "*")
    @test read(pipe) == 2
    @test length(read(pipe)) == 0
    disconnect(pipe)
end
#
@testset "Pub/Sub" begin
    # Pub/Sub is only synchronous/blocking
    # g(y) = print(y)
    # channel1cb(y) = println("channel func 1: ", y)
    # channel2cb(y) = println("channel func 2: ", y)
    # channel3cb(y) = println("channel func 3: ", y)
    # subs = SubscriptionConnection()
    # s1 = subscribe(subs, "channel1", channel1cb)
    # s2 = subscribe(subs, "channel2", channel2cb)
    # s3 = psubscribe(subs, "ch*", channel3cb)
end

@testset "Sentinel" begin
    flushall(conn)
    redispath = joinpath("/",split(info(conn, "server")["executable"], '/')[2:end-1]...)
    confpath = dirname(@__FILE__)
    info("adding slaves to master")
        for port in [6380, 6381]
            run(`$redispath/redis-server --port $port --slaveof 127.0.0.1 6379 --daemonize yes`)
        end
    info("starting sentinels...")
        ports = zip(10001:10003, 6379:6381)
        sentconns = Array{SentinelConnection, 1}(0)
        sentrunids = Array{AbstractString, 1}(0)
        for (sentport, srvport) in ports
            open(joinpath(confpath, "sentinel-$sentport.conf"), "w") do fh
                write(fh, "port $sentport\n")
                write(fh, "daemonize yes\n")
                write(fh, "sentinel monitor mymaster 127.0.0.1 $srvport 2\n")
                write(fh, "sentinel down-after-milliseconds mymaster 2000\n")
            end
            run(`$redispath/redis-sentinel $confpath/sentinel-$sentport.conf`)
            sleep(2)
            sc = SentinelConnection(port=sentport)
            push!(sentrunids, info(sc, "server")["run_id"])
            push!(sentconns, sc)
        end
    info("tests...")
        reply = sentinel_slaves(sentconns[1], "mymaster")
        ix = find(x->x=="name", reply)
        reply = reply[ix+1]
        @test contains(==, reply, "127.0.0.1:6380")
        @test contains(==, reply, "127.0.0.1:6381")
        for (sentconn, (sentport, srvport)) in zip(sentconns, ports)
            @test contains(==, sentinel_master(sentconn, "mymaster"), string(srvport))
            @test contains(==, sentinel_masters(sentconn), string(srvport))
            reply = sentinel_ckquorum(sentconn, "mymaster")
            # for as yet unknown reason one sentinel can sometimes be found in unusable state
            @test (reply == "OK 3 usable Sentinels. Quorum and failover authorization can be reached") ||
                  (reply == "OK 2 usable Sentinels. Quorum and failover authorization can be reached")
            @test sentinel_getmasteraddrbyname(sentconn, "mymaster") == ["127.0.0.1", string(srvport)]
            rm(joinpath(confpath, "sentinel-$sentport.conf"))
            removed = !isfile(confpath, "sentinel-$sentport.conf")
            @test sentinel_flushconfig(sentconn) == "OK"
            rewritten = isfile(confpath, "sentinel-$sentport.conf")
            @test removed && rewritten
        end
        @test sentinel_failover(sentconns[1], "mymaster") == "OK"
        @test sentinel_reset(sentconns[1], "mymaster") == 1
        # the following give incorrect results, even in redis-cli... check this further
        #reply = sentinel_sentinels(sentconns[1], "mymaster")
        #ix = find(x->x=="runid", reply)
        #@test reply[ix+1] == [sentrundis[2] seentrunids[3]]

    info("cleanup sentinels")
        for sentconn in sentconns
            port = info(sentconn, "server")["tcp_port"]
            shutdown(sentconn)
            rm(joinpath(confpath, "sentinel-$port.conf"))
        end
        for port in [6380, 6381]
            shutdown(RedisConnection(port=port))
        end
        isfile(joinpath(confpath, "dump.rdb")) && rm(joinpath(confpath, "dump.rdb"))
end

@testset "Cluster:WIP" begin
    # redispath = joinpath("/",split(info(conn, "server")["executable"], '/')[2:end-1]...)
    # confpath = joinpath(Pkg.dir("Redis", "test"))
    # clusterpath = joinpath(homedir(), "Downloads", "redis-unstable", "utils", "create-cluster")
    # srcpath = joinpath(homedir(), "Downloads", "redis-unstable")
    # cd(clusterpath)

    # info("starting cluster nodes and creating cluster using modified redis-trib.rb")
    #     run(`$clusterpath/create-cluster start`)
    #     run(`$clusterpath/create-cluster create`)
    # cluster_conn = RedisConnection(port=30001)
    # # replace array with dict or new Cluster type enabling lookup node id / ipport / slave-master / slots
    # nodes = map(ClusterNode, cluster_nodes(cluster_conn))
    # @test length(nodes) == 6 # default value in create_cluster script
    # [@test x.linkstate == "connected" for x in nodes]
    # reply = cluster_info(cluster_conn)
    # @test reply["cluster_slots_assigned"] == "16384"
    # @test reply["cluster_state"] == "ok"
    # @test reply["cluster_size"] == "3"
    # @test reply["cluster_known_nodes"] == "6"

    # info("create one more node")
    #     run(`$redispath/redis-server --port 30007 --cluster-enabled yes --daemonize yes`)
    # @test cluster_meet(cluster_conn, "127.0.0.1", 30007) == "OK"
    # nodes = map(ClusterNode, cluster_nodes(cluster_conn))
    # @test length(nodes) == 7
    # # need to search through `nodes` to find this id
    # @test cluster_forget(cluster_conn, "e48f6ebb8042e3ffcb7bb225dbad0ad4ef661b43") == "OK"
    # @test cluster_reset(cluster_conn)
    # @test length(cluster_nodes(cluster_conn))) == 1 # this node is now disconnected from cluster
    # cluster2_conn = RedisConnection(port=30002)
    # nodes2 = map(ClusterNode, cluster_nodes(cluster2_conn))
    # @test length(nodes2) == 7 # and this can be seen here, with one node in disconnected state

    # info("stopping nodes and and cleanup")
    #     run(`$clusterpath/create-cluster stop`)
    #     run(`$clusterpath/create-cluster clean`)
end

@testset "GeoSets" begin
    flushall(conn)
    @test geoadd(conn, "Sicily", 13.361389, 38.115556, "Palermo", 15.087269, 37.502669,
     "Catania") == 2
    @test get(geodist(conn, "Sicily", "Palermo", "Catania")) == "166274.1516"
    @test georadius(conn, "Sicily", "15", "37", "100","km")[1] == "Catania"
    @test georadius(conn, "Sicily", "15", "37", "200", "km") == ["Palermo", "Catania"]
    @test georadius(conn, "Sicily", "15", "37", "200", "km", "WITHDIST") ==
        ["Palermo", "190.4424", "Catania", "56.4413"]
    @test georadius(conn, "Sicily", "15", "37", "200", "km", "WITHCOORD") ==
        ["Palermo", "13.36138933897018433", "38.11555639549629859", "Catania",
        "15.08726745843887329", "37.50266842333162032"]
    geoadd(conn, "Sicily", 13.583333, 37.316667, "Agrigento")
    @test georadiusbymember(conn, "Sicily", "Agrigento", "100", "km") == ["Agrigento", "Palermo"]
    @test geohash(conn, "Sicily", "Palermo", "Catania") == ["sqc8b49rny0", "sqdtr74hyu0"]
    pos = geopos(conn, "Sicily", "Palermo", "Catania", "NonExisting")
    @test get(pos[1]) == "13.36138933897018433"
    @test get(pos[2]) == "38.11555639549629859"
    @test get(pos[3]) == "15.08726745843887329"
    @test get(pos[4]) == "37.50266842333162032"
    @test isnull(pos[5])
end

@testset "Sundry" begin
    flushall(conn)
    @test Redis.echo(conn, "astringtoecho") == "astringtoecho"
    @test Redis.ping(conn) == "PONG"
    @test flushall(conn) == "OK"
    @test flushdb(conn) == "OK"
    zadd(conn, testkey, 1.0, "abcd")
    dbgobj = debug_object(conn, testkey, asdict=true)
    @test haskey(dbgobj, "encoding") && dbgobj["encoding"] == "ziplist"
    @test haskey(dbgobj, "serializedlength")
    @test object_refcount(conn, testkey) == parse(Int, dbgobj["refcount"])
    @test get(object_encoding(conn, testkey)) == dbgobj["encoding"]
    sleep(3)
    idle = object_idletime(conn, testkey)
    @test idle > 0
    @test Redis.touch(conn, testkey) == 1
    @test object_idletime(conn, testkey) < idle
end

@testset "Cmds & Info" begin
    flushall(conn)
    @test typeof(command(conn)) == Array{String, 1}
    @test typeof(dbsize(conn)) == Int64

    redisinfo = Redis.info(conn)
    @test issubset(["os", "executable", "process_id", "sync_full"], keys(redisinfo))

    redisinfo = Redis.info(conn, "memory")
    @test issubset(["used_memory_overhead", "maxmemory", "used_memory"], keys(redisinfo))
    rle = Array(role(conn))
    @test rle[1] == "master"
    @test isa(rle[2], Int)
    @test Redis.slaveof(conn, "localhost", 6379) == "OK"
    @test slaveof(conn, "no", "one") == "OK"
    tm = Redis.time(conn)
    @test typeof(tm) == Array{String,1}
    @test length(tm) == 2
    @test isa(Dates.unix2datetime(get(tryparse(Int, tm[1]))), DateTime)
end

@testset "Save" begin
    flushall(conn)
    @test bgrewriteaof(conn) == "Background append only file rewriting started"
    sleep(3)
    @test bgsave(conn) == "Background saving started"
    sleep(10)
    @test Redis.save(conn) == "OK"
    @test typeof(lastsave(conn)) == Int64
end

@testset "Client" begin
    flushall(conn)
    @test client_setname(conn, s1) == "OK"
    @test get(client_getname(conn)) == s1
    begin
        tic()
        client_pause(conn, 2000)
        client_getname(conn) == s1
        @test toq() > 2
    end
    clients = client_list(conn, asdict=true)
    @test typeof(clients) == Array{Dict{AbstractString,Any},1}
    # test a few items
    @test issubset(["addr", "psub", "age", "events", "name", "id"], keys(clients[1]))
end

@testset "Config" begin
    flushall(conn)
    result = config_get(conn, "*")
    # select a few items that should appear in result
    @test issubset(["dbfilename", "requirepass", "masterauth"], collect(keys(result)))
    oldconfig = config_get(conn, "save")["save"]
    newsave = "900 1 100 10 60 10000"
    @test config_set(conn, "save", "$newsave") == "OK"
    @test config_get(conn, "save") == Dict("save" => newsave)
    # under new permissioning on my test system user cannot rewrite config
    # fix this by creating redis test instance
    @test config_rewrite(conn) == "ERR Rewriting config file: Permission denied"
    # lines  = readlines(Redis.info(conn, "server", asdict=true)["config_file"], chomp=false)
    # @test findfirst(lines, "save 100 10\n") > 0
    # config_set(conn, "save", oldconfig)
    # config_rewrite(conn) == "OK"

    # test a few reset stats
    before_reset = Redis.info(conn, "stats", asdict=true)
    @test typeof(before_reset) == Dict{AbstractString, AbstractString}
    @test parse(Int, before_reset["keyspace_hits"]) > 0
    @test parse(Int, before_reset["total_commands_processed"]) > 0
    @test config_resetstat(conn) == "OK"
    after_reset = Redis.info(conn, "stats", asdict=true)
    @test parse(Int, after_reset["keyspace_hits"]) == 0
    @test parse(Int, after_reset["total_commands_processed"]) == 1
end

disconnect(conn)
