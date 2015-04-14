# # Memory Queue

# Simple in-memory implementation. Use for development purposes only;
# doesn't work or scale accross processes.
# Yes, you need that even if you don't think so.

uuid              = require 'node-uuid'

CONSUME_INTERVAL  = parseInt(process.env.MEMORY_QUEUE_CONSUME_INTERVAL, 10) or 10

class MemoryQueue
  constructor: (@manager, @options)->
    @tasks   = {}
    @paused  = false
    @ivy     = null

    @listening = false
    @consumeInterval = null

  setupMain: (@ivy) ->

  setupQueue: (@options, cb) ->
    cb null

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
      done     = queues
    else
      done new Error "Multiple queues not supported by memory backend yet :("

    @tasks = {}
    done null

  getScheduledTasks: (cb) ->
    tasks = {}
    for k, v of @tasks
      tasks[k] = JSON.parse v
    cb null, tasks

  sendTask: ({name, options, args}, cb) ->
    taskId = uuid.v4()
    @tasks[taskId] = JSON.stringify {name, options, args}
    cb? null, taskId

  consumeTasks: ->
    for taskId of @tasks
      @manager.emit 'messageRetrieved', @tasks[taskId]
      taskArgs = JSON.parse @tasks[taskId]

      @manager.emit 'scheduledTaskRetrieved',
        id:        taskId
        name:      taskArgs.name
        args:      taskArgs.args
        options:   taskArgs.options

  taskExecuted: (err, result) ->
    delete @tasks[result.id] if result?.id

  listen: (options, cb) ->
    @listening = true
    @consumeInterval = setInterval (=> @consumeTasks() if @listening), CONSUME_INTERVAL unless @consumeInterval
    cb? null

  stopListening: ->
    clearInterval @consumeInterval
    @consumeInterval = null
    @listening = false

module.exports = {
  MemoryQueue
}
