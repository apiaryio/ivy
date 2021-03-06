
{EventEmitter} = require 'events'
logger         = require './logger'
queues         = require './queues'
{notifier}     = require './notifiers'

manager        = queues.queue

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
    manager.on 'scheduledTaskRetrieved', @onScheduledTaskRetrieved.bind(@)

    manager.setupMain @
    notifier.setupMain @

  onScheduledTaskRetrieved: ->
    @scheduledTaskRetrieved.apply @, arguments

  ###
  # Producer & Consumer: Task registration and handling
  ###

  registerTask: (func, funcCb, options={}) ->
    if typeof funcCb is 'object'
      options = funcCb
      funcCb  = null

    if typeof func isnt 'function'
      throw new Error "First parameter 'func' isn't function is #{func}"

    {name} = options
    if not name
      name = func.name

    if not name
      logger.error "Cannot determine task name. Please pass it explicitly through options."
      throw new Error "Cannot determine task name. Please pass it explicitly through options."
    else
      delete options.name

    queueName = options.queue
    if queueName
      delete options.queue

    @taskRegistry[name] = {
      func
      funcCb
      options
      queue: queueName
    }

    @taskObjectRegistry[func] = name

    logger.silly "Registered task #{name} into queue #{queueName}"

  ###
  # Producer & Consumer testing: Clear tasks between tests
  ###
  clearTasks: ->
    @taskRegistry       = {}
    @taskObjectRegistry = {}


  ###
  # Consumer: Resolving tasks recieved from queue and calling them
  ###

  scheduledTaskRetrieved: ({id, name, args, options, queue}) ->
    called = false
    logger.silly "Retrieved task id #{id}"
    @executeTask name, args, (err, result...) =>
      if called
        logger.error "IVY_ERROR Task #{name} called callback multiple times. It shouldn't do that."
      else
        called = true
        notify = !!@taskRegistry[name].funcCb
        # last argument is the callback I am in
        args.pop()
        @emit 'taskExecuted', err, {id, name, args, options, result, notify, queue}


  executeTask: (name, args, cb) ->
    if not @taskRegistry[name]
      cb new Error "Task #{name} not found in registry on consumer"
    else
      logger.silly "Executing task #{name}"
      try
        args.push cb
        @taskRegistry[name].func.apply @taskRegistry[name].func, args
      catch err
        logger.error "IVY_ERROR Ivy task #{name} has thrown an exception. It should call back instead", err
        cb err

  ###
  # Producer: Resolving task return/call values back to callback/handler
  #           and resuming workflow
  ###

  taskResultRetrieved: (data) ->
    try
      result = JSON.parse data
    catch err
      logger.error 'IVY_BAD_ARGUMENTS Recieved JSON unparseable function description. Error is: ', err
      return false

    @resumeCaller result.name, result.args



  resumeCaller: (name, args) ->
    @taskRegistry[name].funcCb.apply @taskRegistry[name].funcCb, args
    @emit 'callerResumed', name, args

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

    name = @taskObjectRegistry[func]
    queueName = manager.queue.getQueueName(@taskRegistry[name].queue or @taskRegistry[name].queueName)

    logger.silly "Sending delayedCall for function #{name} into queue #{queueName} to backend #{manager.currentQueueType} with args", args

    manager.sendTask
      name:    name
      options: @taskRegistry[name].options
      queue:   queueName
      args:    args
    , (err) ->
      cb err

  ###
  # Producer: Knowing where to queue tasks
  ###

  setupQueue: ->
    manager.setupQueue.apply manager, arguments

  ###
  # Consumer: listening to queue events
  ###

  listen: (options, cb) ->
    if typeof options is 'function'
      cb    = options
      options = {}

    logger.silly "Starting to listen to queue #{manager.queue.BACKEND_NAME}, options", options

    manager.listen.apply manager, [options, cb]

  stopListening: ->
    logger.silly "Stopping queue listener"
    manager.stopListening.apply manager, arguments

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
  #   manager.pause.apply manager, arguments

  # pauseQueue: ->
  #   manager.resume.apply manager, arguments

module.exports = {
  Ivy
}
