{MemoryQueue} = require './memory'

# # Interface to queue
#
# All queue backends must implement this interface
#
# Documentation of particular methods goes here as well.
# Document only idiosyncracies of particular implementations in backend classes
#
# It would be nice to just use Proxy object, but Proxies are now available only with
# --harmony-proxies flag and not in general use
class QueueManager
  QUEUE_TYPES =
    memory: MemoryQueue


  constructor: ->
    @changeQueue 'memory'

  changeQueue: (name, options={}) ->
    if not QUEUE_TYPES[name]
      throw new Error "Queue #{name} not available."

    @queue = new QUEUE_TYPES[name] options
    @queue.setupMain if @ivy

  setupMain: (@ivy) ->
    @queue.setupMain @ivy

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
  getQueueContent: ->
    @queue.getQueueContent.apply @queue, arguments


  ###
  # Producer
  ###

  sendTask: ->
    @queue.sendTask.apply @queue, arguments

  ###
  # Listener
  ###

  listen: ->
    @queue.listen.apply @queue, arguments

  stopListening: ->
    @queue.stopListening.apply @queue, arguments


queue = new QueueManager()

module.exports = {
  queue

  Memory: MemoryQueue
}
