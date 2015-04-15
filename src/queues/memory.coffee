# # Memory Queue

# Simple in-memory implementation. Use for development purposes only;
# doesn't work or scale accross processes.
# Yes, you need that even if you don't think so.

uuid              = require 'node-uuid'

CONSUME_INTERVAL  = parseInt(process.env.MEMORY_QUEUE_CONSUME_INTERVAL, 10) or 10

class MemoryQueue
  BACKEND_NAME = 'memory'
  constructor: (@manager, @options)->
    @tasks   = {}
    @paused  = false
    @ivy     = null

    @listening = false
    @consumeInterval = null

  setupMain: (@ivy) ->

  setupQueue: (@options, cb) ->
    cb null

  getQueueName: (name) ->
    name          ?= @manager.DEFAULT_QUEUE_NAME
    @tasks[name]  ?= {}
    return name

  pause: ->
    @paused = true
    clearInterval @consumeInterval if @consumeInterval
    @consumeInterval = null

  resume: (options={}) ->
    @paused = false
    @consumeInterval = setInterval (=> @consumeTasks() if @listening), CONSUME_INTERVAL unless @consumeInterval
    if options.immediatePush
      @consumeTasks()

  clear: (queues, done) ->
    if typeof queues is 'function'
      done = queues
      @tasks = {}
    else
      for queue in queues
        @tasks[queue] = {}

    done null

  getScheduledTasks: (options, cb) ->
    if typeof options is 'function'
      cb = options
      options = {}

    tasks = {}
    for k, v of @tasks[@getQueueName(options.queue)]
      tasks[k] = JSON.parse v

    cb null, tasks

  sendTask: ({name, options, args, queue}, cb) ->
    taskId = uuid.v4()
    @tasks[@getQueueName(queue)][taskId] = JSON.stringify {name, options, args}
    cb? null, taskId

  consumeTasks: (queues) ->
    if queues?.length > 1
      throw new Error "Multiple queues on a single listener not supported yet. Next release."

    queueName = @getQueueName(queues?[0])

    for taskId of @tasks[queueName]
      task = @tasks[queueName][taskId]
      
      @manager.emit 'messageRetrieved', queueName, task
      
      taskArgs = JSON.parse task

      @manager.emit 'scheduledTaskRetrieved',
        id:        taskId
        name:      taskArgs.name
        args:      taskArgs.args
        options:   taskArgs.options
        queue:     queueName

  taskExecuted: (err, result) ->
    delete @tasks[result.queue][result.id] if result?.id

  listen: (mqOptions, queues, cb) ->
    if typeof queues is 'function'
      cb = queues
      queues = [@getQueueName(mqOptions.queueName)]

    @listening = true
    @consumeInterval = setInterval (=> @consumeTasks(queues) if @listening), CONSUME_INTERVAL unless @consumeInterval
    cb? null

  stopListening: ->
    clearInterval @consumeInterval
    @consumeInterval = null
    @listening = false

module.exports = {
  MemoryQueue
}
