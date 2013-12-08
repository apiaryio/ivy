{queue} = require './queues'

class Ivy
  constructor: (options) ->
    {
      @config
    } = options

    @taskRegistry       = {}
    @taskObjectRegistry = {}

    @listener = null


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

  callTask: (name, args) ->
    if not @taskRegistry[name]
      return new Error "Task #{name} not found in registry on consumer"
    else
      return @taskRegistry[name].func.apply @taskRegistry[name].func, args

  delayedCall: ->
    func = arguments.slice 0, 1
    cb   = arguments.slice arguments.length-1
    if arguments.length > 2
      args = arguments.slice 1, arguments.length-1
    else
      args = []

    queue.sendTask
      name:    @taskObjectRegistry[func]
      options: @taskRegistry[@taskObjectRegistry[func]].options
      args:    JSON.parse JSON.stringify args
    , cb

  delayedCallSync: ->
    fargs = Array.prototype.slice.call(arguments)
    func = fargs.slice 0, 1
    args = fargs.slice(1) or []
    queue.sendTask
      name:    @taskObjectRegistry[func]
      options: @taskRegistry[@taskObjectRegistry[func]].options
      args:    JSON.parse JSON.stringify args


  listen: ->
    queue.listen.apply queue, arguments

  stopListening: ->
    queue.stopListening.apply queue, arguments



module.exports = {
  Ivy
}
