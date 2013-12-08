# # Memory Queue

# Simple in-memory implementation. Use for development purposes only;
# doesn't work or scale accross processes.
# Yes, you need that even if you don't think so.


class MemoryQueue
  constructor: ->
    @tasks  = []
    @paused = false


  pause: ->
    @paused = true

  resume: ->
    @paused = false

  getQueueContent: (cb) ->
    cb null, @tasks

  sendTask: ({name, options, args}, cb) ->
    @tasks.push {name, options, args}
    cb? null


module.exports = {
  MemoryQueue
}
