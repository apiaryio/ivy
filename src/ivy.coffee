{EventEmitter} = require 'events'

{queue}        = require './queues'
{notifier}     = require './notifiers'

class Ivy extends EventEmitter
  constructor: (options) ->
    {
      @config
    } = options

    @taskRegistry       = {}
    @taskObjectRegistry = {}

    super("Ivy")

  # Setup main "singleton" instance of ivy that is used when requiring it
  setupMain: ->
    queue.on 'scheduledTaskRetrieved', =>
      @scheduledTaskRetrieved.apply @, arguments

    queue.setupMain    @
    notifier.setupMain @

  ###
  # Producer & Consumer: Task registration and handling
  ###

  registerTask: (func, funcCb, options={}) ->
    if typeof funcCb is 'object'
      options = funcCb
      funcCb  = null

    {name} = options
    if not name
      name = func.name

    if not name
      throw new Error "Cannot determine task name. Please pass it explicitly through options."

    @taskRegistry[name] = {
      func
      funcCb
      options
    }

    @taskObjectRegistry[func] = name


  ###
  # Consumer: Resolving tasks recieved from queue and calling them
  ###

  scheduledTaskRetrieved: ({id, name, args, options}) ->
    called = false
    @executeTask name, args, (err, result...) =>
      if called
        console.error "IVY_ERROR Task #{name} called callback multiple times. Is shouldn't do that."
      else
        called = true
        # last argument is the callback I am in
        args.pop()
        @emit 'taskExecuted', err, {id, name, args, options, result}


  executeTask: (name, args, cb) ->
    if not @taskRegistry[name]
      cb new Error "Task #{name} not found in registry on consumer"
    else
      try
        args.push cb
        @taskRegistry[name].func.apply @taskRegistry[name].func, args
      catch err
        console.error "IVY_ERROR Ivy task #{name} has thrown an exception. It should call back instead", err
        cb err

  ###
  # Producer: Resolving task return/call values back to callback/handler
  #           and resuming workflow
  ###

  taskResultRetrieved: (data) ->
    try
      result = JSON.parse data
    catch err
      console.error 'IVY_BAD_ARGUMENTS Recieved JSON unparseable function description. Error is: ', err
      return false

    @resumeCaller result.name, result.args



  resumeCaller: (name, args) ->
    @taskRegistry[name].funcCb.apply @taskRegistry[name].funcCb, args    


  ### 
  # Producer: Main "start it all" API: Calling "delayed/remote" functions as if they were local
  ###

  cleanArguments: (args) ->
    JSON.parse JSON.stringify args

  # Signature: ivy.delayedCall function, [arg1, arg2, argN],
  #   placedIntoQueueSuccessfullyCallback
  delayedCall: ->
    fargs  = Array.prototype.slice.call(arguments)
    func   = fargs.slice(0, 1)[0]
    cb     = fargs.slice(arguments.length-1)[0]

    if fargs.length > 2
      args = fargs.slice 1, arguments.length-1
    else
      args = []

    try
      args = @cleanArguments args
    catch err
      return cb err

    queue.sendTask
      name:    @taskObjectRegistry[func]
      options: @taskRegistry[@taskObjectRegistry[func]].options
      args:    args
    , (err) ->
      cb err

  delayedCallSync: ->
    fargs = Array.prototype.slice.call(arguments)
    func  = fargs.slice 0, 1
    args  = fargs.slice(1) or []
    queue.sendTask
      name:    @taskObjectRegistry[func]
      options: @taskRegistry[@taskObjectRegistry[func]].options
      args:    JSON.parse JSON.stringify args

  ###
  # Consumer: listening to queue events
  ###

  listen: ->
    queue.listen.apply queue, arguments

  stopListening: ->
    queue.stopListening.apply queue, arguments

  ###
  # Consumer & Producer: consuming/producing task notifications
  ###

  startNotificationProducer: (options, cb) ->
    if typeof options is 'function'
      cb    = options
      options = {}
    notifier.startProducer options, cb

  startNotificationConsumer: (options, cb) ->
    if typeof options is 'function'
      cb    = options
      options = {}

    notifier.startConsumer options, cb

  pauseNotifier: (cb) ->
    notifier.pause cb

  resumeNotifier: (options, cb) ->
    if typeof options is 'function'
      cb    = options
      options = {}
    notifier.resume options, cb


  # resumeQueue: ->
  #   queue.pause.apply queue, arguments

  # pauseQueue: ->
  #   queue.resume.apply queue, arguments

module.exports = {
  Ivy
}
