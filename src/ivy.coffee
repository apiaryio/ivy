{queue} = require './queues'

class Ivy
  constructor: (options) ->
    {
      @config
    } = options

    @taskRegistry       = {}
    @taskObjectRegistry = {}


  registerTask: (func, options={}) ->
    {name} = options
    if not name
      name = func.name

    if not name
      throw new Error "Cannot determine task name. Please pass it explicitly through options."

    @taskRegistry[name] = {
      func: func,
      options
    }

    @taskObjectRegistry[func] = name

  delayedCall: (func, args, cb) ->
    queue.sendTask
      name:    @taskObjectRegistry[func]
      options: @taskRegistry[@taskObjectRegistry[func]].options
      args:    JSON.parse JSON.stringify args
    , cb


module.exports = {
  Ivy
}
