{MemoryNotifier} = require './memory'

# # Interface to notifiers
#
# All notifiers backends must implement this interface
#
# Documentation of particular methods goes here as well.
# Document only idiosyncracies of particular implementations in backend classes
#
# It would be nice to just use Proxy object, but Proxies are now available only with
# --harmony-proxies flag and not in general use

class NotificationManager
  NOTIFIER_TYPES =
    memory: MemoryNotifier


  constructor: ->
    @changeNotifier 'memory'

  changeNotifier: (name, options={}) ->
    if not NOTIFIER_TYPES[name]
      throw new Error "Queue #{name} not available."

    @notifier = new NOTIFIER_TYPES[name] options

  setupMain: (@ivy) ->
    @notifier.setupMain @ivy

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


  startProducer: (options, cb) ->
    if options.type
      @changeNotifier options.type, options

    @notifier.startProducer.apply @notifier, arguments

  startConsumer: (options, cb) ->
    if options.type
      @changeNotifier options.type, options

    @notifier.startConsumer.apply @notifier, arguments

  getContent: ->
    @notifier.getContent.apply @notifier, arguments


  sendTaskResult: ->
    @notifier.sendTaskResult.apply @notifier, arguments

notifier = new NotificationManager()

module.exports = {
  notifier

  Memory: MemoryNotifier
}
