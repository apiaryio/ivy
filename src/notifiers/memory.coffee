# # Memory Notifier

# Simple in-memory implementation. Use for development purposes only;
# doesn't work or scale accross processes.
# Yes, you need that even if you don't think so.

{EventEmitter} = require 'events'

{consumeTasks} = require '../listener'

CONSUME_INTERVAL  = parseInt(process.env.MEMORY_NOTIFIER_CONSUME_INTERVAL) or 10

class MemoryNotifier extends EventEmitter
  constructor: ->
    @taskResults     = []
    @ivy             = null
    @paused          = false

    @listening       = false
    @consumeInterval = null

    @producer        = false
    @consumer        = false

    super("MemoryNotifier")

  setupMain: (@ivy) ->

  consumeTasks: ->
    for taskResult in @taskResults
      @ivy.taskResultRetrieved taskResult

    @taskResults.length = 0


  pause: (done) ->
    @paused = true
    @pausedInterval = @consumeInterval
    clearInterval(@consumeInterval) if @consumeInterval
    done null

  resume: (options={}, done) ->
    if typeof options is 'function'
      done    = options
      options = {}

    @paused = false
    @consumeInterval = setInterval (=> @consumeTasks()), CONSUME_INTERVAL if @pausedInterval
    if options.immediate
      @consumeTasks()

    done null

  startProducer: (options, cb) ->
    @paused   = false
    @producer = true
    cb null

  startConsumer: (options, cb) ->
    @paused   = false
    @consumer = true

    @consumeInterval = setInterval (=> @consumeTasks()), CONSUME_INTERVAL unless @consumeInterval
    if options.immediate
      @consumeTasks()

    cb null

  getNotifications: (cb) ->
    cb null, @taskResults

  sendTaskResult: ({name, options, args}, cb) ->
    @taskResults.push JSON.stringify {name, options, args}
    cb? null

module.exports = {
  MemoryNotifier
}
