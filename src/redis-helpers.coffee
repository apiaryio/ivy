url       = require 'url'

async     = require 'async'
redis     = require 'redis'

# Use dedicated single connection for ivy because of simplicity.
# TODO: Allow a way to pass the connection from application
REDIS_CONNECTIONS = {}

parseUrl = (redisUrl) ->
  parsed = url.parse redisUrl
  parsed.password = parsed.auth.split(":")?[1] if parsed.auth
  return parsed


createClient = (name) ->
  options = {}

  # setup options/auth from environment
  if process.env.REDIS_URL
    options = parseUrl process.env.REDIS_URL
    if ':' in options.host
      wholeHost = options.host.split(':')
      options.host = wholeHost[0]
      if options.port and options.port isnt wholeHost[1]
        console.error "Parsing error: url.parsed() port is #{options.port}, but hostname leftover is #{wholeHost[1]}", new Error()

  # provide defaults

  # I'd love to disable queue buffering as it leads to bad error conditions, as
  # we have already seen in mongo, otherwise there is a "setup race condition"
  # and we may retrieve errors
  #
  # However, that would require us to set up server *after* connection event has
  # been emmited

  # So, basically, TODO & refactor later ;)
  # options.enable_offline_queue ?= false

  # create client & return execute
  client = redis.createClient options.port or '6379', options.host or '127.0.0.1', options
  if options.password then client.auth options.password, (err) -> if err then console.error 'Cannot authorize client', err #else console.log "Redis client authorized"

  client.on 'ready', -> # console.log 'Redis client ready, executing queued commands'
  client.on 'end',   -> # console.log 'Redis connection closed'

  # This is somehow controversial, because it is basically similar to "empty except"
  # However, at the current state of affairs, application is still somehow usable,
  # so we just report it to nervous developers to hipchat & carry on
  # Also, as far as I can see, there is no way to associate errors with operations
  # except for creating an client *per "transaction"*, which I'd consider overkill,
  # as handshake requires certain overhead (in terms of latency etc). 
  # However, I have not measured it and it might be an option for us in the future.
  client.on 'error', (err) ->
    console.error "Redis client emmited error: ", err

  REDIS_CONNECTIONS[name] = client
  client.name = name

  if parseInt(process.env.REDIS_DATABASE, 10) > 0
    client.select parseInt(process.env.REDIS_DATABASE, 10)

  return client


getClient = (name='standard') -> REDIS_CONNECTIONS[name] or createClient name

flush = (cb) ->
  async.each (i for i of REDIS_CONNECTIONS), (con, next) ->
    if REDIS_CONNECTIONS[con].pub_sub_mode
      REDIS_CONNECTIONS[con].unsubscribe next
    else
      REDIS_CONNECTIONS[con].flushdb next
  , cb


disconnect = (cb) ->
  for con of REDIS_CONNECTIONS
    REDIS_CONNECTIONS[con].quit()
  cb null


module.exports = {
  getClient
  flush
  disconnect
  parseUrl
}
