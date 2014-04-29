# # Redis PubSub Notifier

# Redis notification using Pub/Sub semantics
# Note that this doesn't guarantee notification delivery
# (when `Producer` is offline / has hiccups),
# but this might be OK in your architecture.

redis    = require 'redis'
redutils = require '../redis-helpers'
logger   = require '../logger'

CONSUME_INTERVAL = parseInt(process.env.MEMORY_NOTIFIER_CONSUME_INTERVAL) or 10

class RedisPubSubNotifier
  constructor: (@manager, @options) ->
    @taskResults     = []
    @ivy             = null
    @paused          = false

    @listening       = false
    @consumeInterval = null

    @producer        = false
    @consumer        = false

    @pubClient       = null
    @subClient       = null

  setupMain: (@ivy) ->

  consumeTasks: ->
    for taskResult in @taskResults
      @ivy.taskResultRetrieved taskResult

    @taskResults.length = 0


  pause: (done) ->
    @paused = true
    done null

  resume: (options={}, done) ->
    if typeof options is 'function'
      done    = options
      options = {}

    @paused = false

    for task in @taskResults
      @sendTaskResult JSON.parse task
    @taskResults.length = 0

    done null

  clear: (cb) ->
    @taskResults.length = 0
    redutils.flush (err) ->
      cb err

  startProducer: (options, cb) ->
    @pubClient = redutils.getClient 'ivy-pub'
    @producerChannel = options.channel or process.env.IVY_NOTIFICATION_CHANNEL_NAME or @manager.DEFAULT_NOTIFICATION_CHANNEL_NAME

    if @consumerChannel and @producerChannel isnt @consumerChannel
      logger.warn "IVY_WARNING Creating notification producer/pub client for channel #{@producerChannel}, but consumer channel is #{@consumerChannel}. Double-check that you want this."

    @pubClient.once 'ready', (err) ->
      cb err

  startConsumer: (options, cb) ->
    @subClient       = redutils.getClient 'ivy-sub'
    @consumerChannel = options.channel or process.env.IVY_NOTIFICATION_CHANNEL_NAME or @manager.DEFAULT_NOTIFICATION_CHANNEL_NAME

    if @producerChannel and @producerChannel isnt @consumerChannel
      logger.warn "IVY_WARNING Subsribing to notification consumer/sub channel #{@consumerChannel}, but producer/pub channel is #{@producerChannel}. Double-check that you want this."

    @subClient.once 'ready', (err) =>
      if err then return cb err

      @subClient.once 'subscribe', (channelName, count) =>
        if channelName isnt @consumerChannel
          message = "IVY_REDIS_ERROR I've asked to subscribe to #{@consumerChannel}, but got into #{channelName} instead!"
          logger.error message
          return cb new Error channelName
        else
          cb null

      @subClient.once 'message', (channel, message) =>
        if channel is @consumerChannel
          @ivy.taskResultRetrieved message

      @subClient.subscribe @consumerChannel, (err) ->
        if err then cb err

  # unsupported by redis; use only 'manual helper test buffer'
  getNotifications: (cb) ->
    cb null, @taskResults

  sendTaskResult: ({id, name, options, args}) ->
    message = JSON.stringify {id, name, options, args}

    if @paused
      @taskResults.push message
    else
      @pubClient.publish @producerChannel, message

    @manager.emit 'taskResultSend', null, {id, name, options, args}

module.exports = {
  RedisPubSubNotifier
}
