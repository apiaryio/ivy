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

  callTaskSync: (name, args) ->
    if not @taskRegistry[name]
      result = new Error "Task #{name} not found in registry on consumer"
      @taskDone result
    else
      try
        result = @taskRegistry[name].func.apply @taskRegistry[name].func, args
        @taskDone null, result

      catch err
        @taskDone err
      
    return result

  callTask: (name, args) ->
    if not @taskRegistry[name]
      @taskDone new Error "Task #{name} not found in registry on consumer"
    else
      try
        args.push (err, args...) =>
          @taskDone err, name, args

        @taskRegistry[name].func.apply @taskRegistry[name].func, args
      catch err
        @taskDone err

  ###
  # Consumer: Pushing resolved tasks back to notification channel
  ###

  taskDone: (err, name, args...) ->
    @emit 'taskExecuted', err, name or 'dummyTaskName', args 

    #@ notifier.sendTaskResult name, args unless err


  ###
  # Producer: Resolving task return/call values back to callback/handler
  #           and resuming workflow
  ###

  resolveTask: (name, args) ->
    @taskRegistry[name].funcCb.apply @taskRegistry[name].funcCb, args    


  ### 
  # Producer: Main "start it all" API: Calling "delayed/remote" functions as if they were local
  ###


  # Signature: ivy.delayedCall function, arg1, arg2, argN,
  #   delayedCallCallback (err)
  delayedCall: ->
    fargs               = Array.prototype.slice.call(arguments)
    func                = fargs.slice(0, 1)[0]
    delayedCallCallback = fargs.slice(arguments.length-1)[0]

    if fargs.length > 2
      args = fargs.slice 1, arguments.length-1
    else
      args = []

    queue.sendTask
      name:    @taskObjectRegistry[func]
      options: @taskRegistry[@taskObjectRegistry[func]].options
      args:    JSON.parse JSON.stringify args
    , (err) ->
      delayedCallCallback err

  delayedCallSync: ->
    fargs = Array.prototype.slice.call(arguments)
    func = fargs.slice 0, 1
    args = fargs.slice(1) or []
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

  startNotificationProducer: (options, done) ->
    notifier.startProducer options, done

  startNotificationConsumer: (options, done) ->
    notifier.startConsumer options, done

  pauseNotifier: (done) ->
    notifier.pause done

  resumeNotifier: (done) ->
    notifier.resume done


  # resumeQueue: ->
  #   queue.pause.apply queue, arguments

  # pauseQueue: ->
  #   queue.resume.apply queue, arguments

module.exports = {
  Ivy
}
