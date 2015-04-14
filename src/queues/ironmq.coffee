# # IronMQ Queue

# Backend that utilizes [IronMQ](http://www.iron.io/mq) using
# their [node.js library](https://github.com/iron-io/iron_mq_node)
async    = require 'async'
ironMQ   = require 'iron_mq'

logger      = require '../logger'
tokencrypto = require '../tokencrypto'

CONSUME_INTERVAL  = parseInt(process.env.IRONMQ_CONSUME_INTERVAL, 10) or 1000
IRONMQ_LIMIT = 65536

class IronMQQueue
  constructor: (@manager, @options)->
    @tasks   = {}
    @paused  = false
    @ivy     = null
    @client  = null
    @queues  = {}

    @listening  = false
    @encryption = false
    @encryptionKey = ''
    @configured = false
    @consumeInterval = null

  setupMain: (@ivy) ->

  setupQueue: (@options, cb) ->
    queueName = @options.queueName or @manager.DEFAULT_QUEUE_NAME

    if @options.encryptionKey
      @encryption = true
      @encryptionKey = @options.encryptionKey

    if not @options.auth?.token or not @options.auth?.projectId
      return cb new Error "Cannot listen to IronMQ without authentication"

    @client   = new ironMQ.Client
      token:      @options.auth.token
      project_id: @options.auth.projectId
      queue_name: queueName

    #FIXME: @defaultQueue
    @queues[queueName] ?= @queue

    @configured = false

    cb? null

  getQueue: (name) ->
    name          ?= @manager.DEFAULT_QUEUE_NAME
    @queues[name] ?= @client.queue name
    return @queues[name]

  pause: ->
    @paused = true
    clearInterval @consumeInterval if @consumeInterval
    @consumeInterval = null

  resume: (options={}) ->
    @paused = false
    @consumeInterval = setInterval (=> @consumeTasks() if @listening), CONSUME_INTERVAL unless @consumeInterval
    if options.immediatePush
      @consumeTasks()

  clear: (queues, cb) ->
    if typeof queues is 'function'
      cb     = queues
      queues = (name for name, q of @queues)

    async.forEach queues, (name, done) =>
      @getQueue(name).del_queue (err, body) ->
        done err
    , (err) ->
      cb err

  getScheduledTasks: (options, cb) ->
    if typeof options is 'function'
      cb = options
      options = {}

    @getQueue(options.queue).peek n: 100, (err, body) =>
      scheduledTasks = {}
      if body
        for t in body
          if tokencrypto.isEncrypted t.body
            tokencrypto.getDecrypted t.body, @encryptionKey, (err, encryptedBody) ->
              if encryptedBody
                try
                  scheduledTasks[t.id] = JSON.parse encryptedBody
                catch e
                  logger.error "IVY_IRONMQ_ERROR Can't parse encryptedBody in getScheduledTasks", e
              else
                cb new Error "IVY_IRONMQ_ERROR Missing encryptionKey"
          else
            try
              scheduledTasks[t.id] = JSON.parse t.body
            catch e
              logger.error "IVY_IRONMQ_ERROR Can't parse body in getScheduledTasks", e
      cb err, scheduledTasks

  postTask: (queueName, name, message, cb) ->
    if (JSON.stringify message).length > IRONMQ_LIMIT
      errorMessage = "IronMQ message exceeed limit #{IRONMQ_LIMIT} - name: #{name}"
      logger.error errorMessage
      cb new Error errorMessage
    logger.debug "ironmq queue #{queueName} sendTask message:", message
    @getQueue(queueName).post message, (err, taskId) ->
      cb err, taskId

  sendTask: ({name, options, queue, args}, cb) ->
    message = {}
    queueName = queue
    body = JSON.stringify {name, options, args}
    if @encryption
      tokencrypto.getEncrypted body, @encryptionKey, (err, encryptedBody) =>
        if err then return cb err
        message.body = encryptedBody
        @postTask queueName, name, message, cb
    else
      message.body = body
      @postTask queueName, name, message, cb

  emitConsumeTask: (message, ironTask) ->
    try
      taskArgs = JSON.parse message
    catch e
      logger.error 'ironTask is', ironTask
      logger.error "IVY_IRONMQ_ERROR Retrieve tasks that cannot be parsed as JSON, deleting from queue: #{ironTask}", e
      @getQueue().del ironTask.id, (err, body) =>
        if err
          logger.warn "IVY_WARNING Cannot delete task from IronMQ", err
          @manager.emit 'mqError', err

    @manager.emit 'scheduledTaskRetrieved',
      id:        ironTask.id
      name:      taskArgs.name
      args:      taskArgs.args
      options:   taskArgs.options

  consumeTasks: ->
    toRetrieve = @options.messageSize or 1
    @getQueue().get n: toRetrieve, (err, ironTasks) =>
      if err
        logger.warn "IVY_WARNING Cannot retrieve task from IronMQ", err
        @manager.emit 'mqError', err if err
        return

      if toRetrieve < 2 and ironTasks #.length > 0
        ironTasks = [ironTasks]

      for ironTask in ironTasks or []
        @manager.emit 'messageRetrieved', ironTasks

        message = ''
        if @encryption
          tokencrypto.getDecrypted ironTask.body, @encryptionKey, (err, descryptedBody) =>
            if err
              logger.warn "IVY_WARNING Cannot decrypt task from IronMQ", err
              @manager.emit 'mqError', err

            message = descryptedBody
            @emitConsumeTask message, ironTask
        else
          message = ironTask.body
          @emitConsumeTask message, ironTask

  taskExecuted: (err, result) ->
    @getQueue().del result.id, (err, body) =>
      if err
        logger.warn "IVY_WARNING Cannot delete task #{result.id} from IronMQ", err
        @manager.emit 'mqError', err

  listen: (options, cb) ->
    @listening = true
    async.series [
      (next) =>
        if @queue
          return next null
        else
          @setupQueue options, next
    ], (err) =>
      @consumeInterval = setInterval (=> @consumeTasks() if @listening), CONSUME_INTERVAL unless @consumeInterval
      cb? err

  stopListening: ->
    clearInterval @consumeInterval
    @listening       = false
    @consumeInterval = null

module.exports = {
  IronMQQueue
}
