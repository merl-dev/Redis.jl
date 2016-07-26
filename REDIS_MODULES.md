## Redis Modules

Redis Modules are a recent feature enabling user-defined add-ons to Redis, scheduled to be included by Redis 4.0.  For references
see:
* http://antirez.com/news/106
* http://redismodules.com/
* https://github.com/RedisLabs/RedisModulesSDK
* https://github.com/RedisLabsModules/pyredis

The hiredis branch of Redis.jl provides methods to initialize, list and unload modules. A number of modules are already available and details can be found at http://redismodules.com/.
The current commit contains several new commands implemented in an online stats module currently under development and found at https://github.com/merl-dev/OST.
I am presently using this client to test that module and the overall performance of this new Redis feature.  The user can consult the test directory of **OST** for details
of some of those tests and usage of the new commands.

### Installation (pre Redis 4.0) and Use

A Redis Modules version needs to be compiled in order to enable module features, and this can be done on Ubuntu by running the following:

```
$wget https://github.com/antirez/redis/archive/unstable.tar.gz
$tar xvzf unstable.tar.gz
$cd redis-unstable && make && sudo make install
```

In addition, the relevant module(s) must be downloaded, installed and loaded into Redis. For example, to install the redex module run the following:

```
$wget https://github.com/RedisLabsModules/redex/archive/master.tar.gz
tar xvzf master.tar.gz
$cd redex-master && make
```

After running 'make`, the module's commands are made available as follows:

```
using Redis
conn = RedisConnection()
module_load(conn, "redex-master/src/rxhashes.so")
```
As with all Redis commands, the Redis.jl API for modules is almost identical to the original command.  For example, the redex module defines a new hash command `HGETSET` which
sets the given hash field and returns its previous value. In Julia, this is called with `hgetset(conn, key, field, value)`.
