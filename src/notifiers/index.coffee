{EventEmitter}        = require 'events'

{MemoryNotifier}      = require './memory'
{RedisPubSubNotifier} = require './redis'

# # Interface to notifiers
#
# All notifiers backends must implement this interface
#
# Documentation of particular methods goes here as well.
# Document only idiosyncracies of particular implementations in backend classes
#
# It would be nice to just use Proxy object, but Proxies are now available only with
# --harmony-proxies flag and not in general use

class NotificationManager extends EventEmitter
  NOTIFIER_TYPES =
    memory: MemoryNotifier
    redis:  RedisPubSubNotifier


  constructor: ->
    @DEFAULT_NOTIFICATION_CHANNEL_NAME = 'ivy-notifier'
    @changeNotifier 'memory'

  changeNotifier: (notifierType, options={}) ->
    unless @currentNotifierType is notifierType
      if not NOTIFIER_TYPES[notifierType]
        throw new Error "Queue #{notifierType} not available."

      @notifier = new NOTIFIER_TYPES[notifierType] @, options
      @currentNotifierType = notifierType

      @notifier.setupMain @ivy if @ivy

  setupMain: (@ivy) ->
    @notifier.setupMain @ivy

    @ivy.on 'taskExecuted', (err, options) =>
      # if err, task failed to execute; do not notify,
      # it shall be retried later
      if not err and options.notify
        @notifier.sendTaskResult.apply @notifier, [options]

  ###
  # Proxy attributes follow
  ###

  ###
  # Management
  ###


  pause: ->
    @notifier.pause.apply @notifier, arguments

  resume: ->
    @notifier.resume.apply @notifier, arguments

  clear: ->
    @notifier.clear.apply @notifier, arguments

  startProducer: (options, cb) ->
    if options.type
      @changeNotifier options.type, options

    @notifier.startProducer.apply @notifier, arguments

  startConsumer: (options, cb) ->
    if options.type
      @changeNotifier options.type, options

    @notifier.startConsumer.apply @notifier, arguments

  getNotifications: ->
    @notifier.getNotifications.apply @notifier, arguments


  sendTaskResult: ->
    @notifier.sendTaskResult.apply @notifier, arguments

notifier = new NotificationManager()

module.exports = {
  notifier

  Memory: MemoryNotifier
  Redis:  RedisPubSubNotifier
}
