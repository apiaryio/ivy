# # IronMQ Queue

# Backend that utilizes [IronMQ](http://www.iron.io/mq) using
# their [node.js library](https://github.com/iron-io/iron_mq_node)
async  = require 'async'
ironMQ = require 'iron_mq'

CONSUME_INTERVAL  = parseInt(process.env.IRONMQ_CONSUME_INTERVAL, 10) or 1000


class IronMQQueue
  constructor: (@manager, @options)->
    @tasks   = {}
    @paused  = false
    @ivy     = null
    @client  = null

    @listening  = false
    @configured = false
    @consumeInterval = null

  setupMain: (@ivy) ->

  setupQueue: (@options, cb) ->
    queueName = @options.queueName or @manager.DEFAULT_QUEUE_NAME

    if not @options.auth?.token or not @options.auth?.projectId
      return cb new Error "Cannot listen to IronMQ without authentication"

    @client   = new ironMQ.Client
      token:      @options.auth.token
      project_id: @options.auth.projectId
      queue_name: queueName

    @queue    = @client.queue queueName
    @configured = false

    cb? null


  pause: ->
    @paused = true
    clearInterval @consumeInterval if @consumeInterval
    @consumeInterval = null

  resume: (options={}) ->
    @paused = false
    @consumeInterval = setInterval (=> @consumeTasks() if @listening), CONSUME_INTERVAL unless @consumeInterval
    if options.immediatePush
      @consumeTasks()

  clear: (cb) ->
    @queue.del_queue (err, body) ->
      cb err

  getScheduledTasks: (cb) ->
    @queue.peek n: 100, (err, body) ->
      scheduledTasks = {}
      if body
        for t in body
          scheduledTasks[t.id] = JSON.parse t.body
      cb err, scheduledTasks

  sendTask: ({name, options, args}, cb) ->
    options.body = JSON.stringify {name, options, args}

    @queue.post options, (err, taskId) ->
      cb err, taskId

  consumeTasks: ->
    toRetrieve = @options.messageSize or 1
    @queue.get n: toRetrieve, (err, ironTasks) =>
      if err
        console.error "IVY_WARNING Cannot retrieve task from IronMQ", err
        @manager.emit 'mqError', err if err
        return

      if toRetrieve < 2 and ironTasks #.length > 0
        ironTasks = [ironTasks]

      for ironTask in ironTasks or []
        @manager.emit 'messageRetrieved', ironTasks

        try
          taskArgs = JSON.parse ironTask.body
        catch e
          console.error 'ironTask is', ironTask
          console.error "IVY_IRONMQ_ERROR Retrieve tasks that cannot be parsed as JSON, deleting from queue: #{ironTask}", e
          @queue.del ironTask.id, (err, body) =>
            if err
              console.error "IVY_WARNING Cannot delete task from IronMQ", err
              @manager.emit 'mqError', err
        

        @manager.emit 'scheduledTaskRetrieved',
          id:        ironTask.id
          name:      taskArgs.name
          args:      taskArgs.args
          options:   taskArgs.options

  taskExecuted: (err, result) ->
    @queue.del result.id, (err, body) =>
      if err
        console.error "IVY_WARNING Cannot delete task #{result.id} from IronMQ", err
        @manager.emit 'mqError', err

  listen: (options, cb) ->
    @listening       = true
    async.series [
      (next) =>
        if @queue
          return next null
        else
          @setupQueue options, next
    ], (err) ->
      @consumeInterval = setInterval (=> @consumeTasks() if @listening), CONSUME_INTERVAL unless @consumeInterval
      cb? err

  stopListening: ->
    clearInterval @consumeInterval
    @listening       = false
    @consumeInterval = null

module.exports = {
  IronMQQueue
}
