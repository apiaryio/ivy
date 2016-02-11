# # IronMQ Queue

# Backend that utilizes [IronMQ](http://www.iron.io/mq) using
# their [node.js library](https://github.com/iron-io/iron_mq_node)
async    = require 'async'
ironMQ   = require 'iron_mq'

logger      = require '../logger'
tokencrypto = require '../tokencrypto'

CONSUME_INTERVAL  = parseInt(process.env.IRONMQ_CONSUME_INTERVAL, 10) or 1000
RESERVE_TIMEOUT = parseInt(process.env.IRONMQ_RESERVE_TIMEOUT, 10) or 10000
IRONMQ_LIMIT = parseInt(process.env.IRONMQ_LIMIT, 10) or 65536

class IronMQQueue
  BACKEND_NAME: 'ironmq'

  constructor: (@manager, @options)->
    @tasks   = {}
    @paused  = false
    @ivy     = null
    @client  = null
    @queues  = {}
    @queueNames = []

    @listening       = false
    @encryption      = false
    @encryptionKey   = ''
    @configured      = false
    @consumeInterval = null

  setupMain: (@ivy) ->

  setupQueue: (@options, cb) ->
    @queueNames = []

    if @options?.queueName and @options.queueName not in @queueNames
      @queueNames.push(@options.queueName)

    queueName = @getQueueName(@options.queueName)

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

  getQueueName: (name) ->
    if not name and not @queueNames.length
      @queueNames = []
      @manager.fillFromTaskRegistry()
      @manager.addDefaultQueueName()

    name or @queueNames[0]

  getQueue: (name) ->
    queueName = @getQueueName(name)
    @queues[queueName] ?= @client.queue(queueName)
    return @queues[queueName]

  pause: ->
    @paused = true
    clearInterval(@consumeInterval) if @consumeInterval
    @consumeInterval = null

  resume: (options={}) ->
    @paused = false
    @consumeInterval = setInterval((=> @consumeTasks() if @listening), CONSUME_INTERVAL) unless @consumeInterval
    if options.immediatePush
      @consumeTasks()

  clear: (queueNames, cb) ->
    if typeof queueNames is 'function'
      cb = queueNames
      queueNames = (queueName for queueName, q of @queues)

    async.each queueNames, @deleteQueue.bind(@), (err) ->
      cb err

  deleteQueue: (queueName, cb) ->
    @getQueue(queueName).del_queue (err, body) ->
      cb err

  parseEncryptedTask: (scheduledTasks, task, cb) ->
    unless task?
      return cb()

    if tokencrypto.isEncrypted(task.body)
      tokencrypto.getDecrypted task.body, @encryptionKey, (err, decryptedBody) ->
        if decryptedBody
          try
            scheduledTasks[task.id] = JSON.parse decryptedBody
          catch e
            logger.error "IVY_IRONMQ_ERROR Can't JSON.parse decryptedBody in parseEncryptedTask", e
        else
          return cb new Error "IVY_IRONMQ_ERROR Missing encryptionKey"
        cb()
    else
      try
        scheduledTasks[task.id] = JSON.parse task.body
      catch e
        logger.error "IVY_IRONMQ_ERROR Can't JSON.parse body in parseEncryptedTask", e
      cb()

  getScheduledTasks: (options, cb) ->
    if typeof options is 'function'
      cb = options
      options = {}

    queueName = @getQueueName(options.queueName)

    @getQueue(queueName).peek_n n: 100, (err, tasksFromQueue = []) =>
      if err
        logger.warn "IVY_WARNING Cannot get scheduled tasks from IronMQ queue #{queueName}", err
        @manager.emit 'mqError', err

      scheduledTasks = {}
      unless tasksFromQueue.length
        return cb(null, scheduledTasks)

      async.each tasksFromQueue, @parseEncryptedTask.bind(@, scheduledTasks), (err) ->
        cb(err, scheduledTasks)

  postTask: (queueName, name, message, cb) ->
    if (JSON.stringify message).length > IRONMQ_LIMIT
      errorMessage = "IronMQ message exceeed limit #{IRONMQ_LIMIT} - name: #{name}"
      logger.error errorMessage
      return cb new Error errorMessage
    logger.debug "ironmq queue '#{queueName}' sendTask message:", message
    @getQueue(queueName).post message, (err, taskId) ->
      cb err, taskId

  sendTask: ({name, options, queueName, args}, cb) ->
    message = {}
    queueNameToUse = @getQueueName(queueName)
    body = JSON.stringify {name, options, args}
    if @encryption
      tokencrypto.getEncrypted body, @encryptionKey, (err, encryptedBody) =>
        if err then return cb err
        message.body = encryptedBody
        @postTask queueNameToUse, name, message, cb
    else
      message.body = body
      @postTask queueNameToUse, name, message, cb

  emitConsumeTask: (message, queueName, ironTask) ->
    try
      taskArgs = JSON.parse message
      taskArgs.options ?= {}
      taskArgs.options.reservation_id = ironTask.reservation_id
    catch e
      logger.error "IVY_IRONMQ_ERROR Retrieve tasks that cannot be parsed as JSON, will be deleted from queue.", e
      logger.warn "IRONTASK", ironTask
      if ironTask.id
        @getQueue(queueName).del ironTask.id, { reservation_id: taskArgs.options.reservation_id }, (err, body) =>
          if err
            logger.warn "IVY_WARNING Cannot delete task from IronMQ queue '#{queueName}'", err
            @manager.emit 'mqError', err
      return

    @manager.emit 'scheduledTaskRetrieved', {
      id:        ironTask.id
      name:      taskArgs.name
      args:      taskArgs.args
      options:   taskArgs.options
      queueName: queueName
    }

  consumeTasks: (queueNames) ->
    toRetrieve = @options.messageSize or 1

    if queueNames?.length > 1
      throw new Error "Multiple queues on a single listener not supported yet. Next release."

    queueName = @getQueueName queueNames?[0]

    @getQueue(queueName).reserve { n: toRetrieve, timeout: RESERVE_TIMEOUT}, (err, ironTasks) =>
      if err
        logger.warn "IVY_WARNING Cannot retrieve task from IronMQ", err
        @manager.emit 'mqError', err if err
        return

      if toRetrieve < 2 and ironTasks #.length > 0
        ironTasks = [ironTasks]

      for ironTask in ironTasks or [] then do (ironTask) =>
        @manager.emit 'messageRetrieved', queueName, ironTask

        message = ''
        if @encryption
          tokencrypto.getDecrypted ironTask.body, @encryptionKey, (err, decryptedBody) =>
            if err
              logger.warn "IVY_WARNING Cannot decrypt task from IronMQ", err
              @manager.emit 'mqError', err

            message = decryptedBody
            @emitConsumeTask message, queueName, ironTask
        else
          message = ironTask.body
          @emitConsumeTask message, queueName, ironTask

  taskExecuted: (err, result) ->
    @getQueue(result.queueName).del result.id, { reservation_id: result.options.reservation_id }, (err, body) =>
      if err
        logger.warn "IVY_WARNING Cannot delete task #{result.id} from IronMQ", err
        @manager.emit 'mqError', err

  listen: (mqOptions, queueNames, cb) ->
    if typeof queueNames is 'function'
      cb = queueNames
      queueNames = [@getQueueName(mqOptions.queueName)]

    @listening = true
    async.series [
      (next) =>
        if @queue
          return next null
        else
          @setupQueue mqOptions, next
    ], (err) =>
      @consumeInterval = setInterval (=> @consumeTasks(queueNames) if @listening), CONSUME_INTERVAL unless @consumeInterval
      cb? err

  stopListening: ->
    clearInterval @consumeInterval
    @listening       = false
    @consumeInterval = null

module.exports = {
  IronMQQueue
}
