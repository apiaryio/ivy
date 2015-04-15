{EventEmitter} = require 'events'

{IronMQQueue}  = require './ironmq'
{MemoryQueue}  = require './memory'

# # Interface to queue
#
# All queue backends must implement this interface.
# Queues shouldn't be EventEmitters, but use @manager.emit instead.
#
# Documentation of particular methods goes here as well.
# Document only idiosyncracies of particular implementations in backend classes
#
# It would be nice to just use Proxy object, but Proxies are now available only with
# --harmony-proxies flag and not in general use (yet).
# TODO: Fix as part of ES6 migration
#
# Queue Manager emits:
# * `messageRetrieved`, queue, {message}
# * `scheduledTaskRetrieved`, {id, name, args, options, queue}
#
# Queue Manager listens to event on @ivy:
# * `taskExecuted` err, {id, name, args, options, result, queue}
#   * ...and dispatches it as method call to backend


class QueueManager extends EventEmitter
  QUEUE_TYPES =
    memory: MemoryQueue
    ironmq: IronMQQueue

  constructor: ->
    @DEFAULT_QUEUE_NAME = 'ivy'
    
    @currentQueue = false
    @changeQueue 'memory'

  changeQueue: (name, options={}) ->
    if not QUEUE_TYPES[name]
      throw new Error "Queue #{name} not available."

    unless @currentQueue is name

      @queue = new QUEUE_TYPES[name] @, options
      @queue.setupMain(@ivy) if @ivy

      @currentQueue = name

  setupMain: (@ivy) ->
    @queue.setupMain @ivy

    @ivy.on 'taskExecuted', =>
      @queue.taskExecuted.apply @queue, arguments

  ###
  # Events
  ###

  ###
  # Proxy attributes follow
  ###

  ###
  # Management
  ###


  # Pause the queue. No tasks will be distributed to workers.
  pause: ->
    @queue.pause.apply @queue, arguments

  # Resume the queue and distribute tasks again
  resume: ->
    @queue.resume.apply @queue, arguments

  # Return tasks from queue that are ready to be processed
  getScheduledTasks: ->
    @queue.getScheduledTasks.apply @queue, arguments

  clear: ->
    @queue.clear.apply @queue, arguments

  ###
  # Producer
  ###

  setupQueue: (options, cb) ->
    if options.type
      @changeQueue options.type, options

    @queue.setupQueue.apply @queue, arguments

  sendTask: ->
    @queue.sendTask.apply @queue, arguments

  ###
  # Consumer
  ###

  # Should be used internally by listener from paritcular queue backend
  # should call @ivy.consumeTask taskName, taskArguments, taskDoneCallback
  # taskDoneCallback signature is (err, result) and result must be serializable
  consumeTasks: ->
    @queue.listen.apply @queue, arguments

  listen: (options, cb) ->
    if options.type
      @changeQueue options.type, options

    @queue.listen.apply @queue, arguments

  stopListening: ->
    @queue.stopListening.apply @queue, arguments


queue = new QueueManager()

module.exports = {
  queue

  Memory: MemoryQueue
  IronMQ: IronMQQueue
}
