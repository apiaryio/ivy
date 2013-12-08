# # Memory Queue

# Simple in-memory implementation. Use for development purposes only;
# doesn't work or scale accross processes.
# Yes, you need that even if you don't think so.

{EventEmitter} = require 'events'

{consumeTasks} = require '../listener'

PUSH_INTERVAL  = parseInt(process.env.MEMORY_QUEUE_PUSH_INTERVAL) or 1

class MemoryQueue extends EventEmitter
  constructor: ->
    @tasks  = []
    @paused = false

    @listener = null
    @pushInterval = null

  pause: ->
    @paused = true
    @pausedInterval = @pushInterval
    clearInterval(@pushInterval) if @pushInterval

  resume: (options={}) ->
    @paused = false
    @pushInterval = setInterval (=> @pushTasks), PUSH_INTERVAL if @pausedInterval
    if options.immediatePush
      @pushTasks()

  getQueueContent: (cb) ->
    cb null, @tasks

  sendTask: ({name, options, args}, cb) ->
    @tasks.push {name, options, args}
    cb? null

  pushTasks: ->
    if @tasks.length > 0
      @emit 'tasks', @tasks
      @tasks.length = 0

  listen: ->
    @on 'tasks', consumeTasks
    @pushInterval = setInterval (=> @pushTasks), PUSH_INTERVAL

  stopListening: ->
    @removeListener 'tasks', consumeTasks
    clearInterval @pushInterval
    @listener = null


module.exports = {
  MemoryQueue
}
