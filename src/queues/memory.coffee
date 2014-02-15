# # Memory Queue

# Simple in-memory implementation. Use for development purposes only;
# doesn't work or scale accross processes.
# Yes, you need that even if you don't think so.

{EventEmitter} = require 'events'

{consumeTasks} = require '../listener'

CONSUME_INTERVAL  = parseInt(process.env.MEMORY_QUEUE_CONSUME_INTERVAL) or 10

class MemoryQueue extends EventEmitter
  constructor: ->
    @tasks  = []
    @paused = false
    @ivy    = null

    @listening = false
    @consumeInterval = null

    super("MemoryQueue")

  setupMain: (@ivy) ->

  pause: ->
    @paused = true
    @pausedInterval = @consumeInterval
    clearInterval(@consumeInterval) if @consumeInterval

  resume: (options={}) ->
    @paused = false
    @consumeInterval = setInterval (=> @consumeTasks), CONSUME_INTERVAL if @pausedInterval
    if options.immediatePush
      @consumeTasks()

  getScheduledTasks: (cb) ->
    cb null, @tasks

  sendTask: ({name, options, args}, cb) ->
    @tasks.push {name, options, args}
    cb? null

  consumeTasks: ->
    if @tasks.length > 0
      @emit 'tasks', @tasks
      @tasks.length = 0

  listen: ->
    @on 'tasks', consumeTasks unless @listening
    @listening = true
    @consumeInterval = setInterval (=> @consumeTasks()), CONSUME_INTERVAL

  stopListening: ->
    @removeListener 'tasks', consumeTasks
    clearInterval @consumeInterval
    @listening = false

module.exports = {
  MemoryQueue
}
