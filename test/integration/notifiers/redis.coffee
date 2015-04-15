{assert}    = require 'chai'

{
  factorial
  factorialSync
  factorialFinished
  factorialFinishedCounterObject
}           = require '../../helpers'

ivy         = require '../../../src'

# internal
{notifier}  = require '../../../src/notifiers'
{queue}     = require '../../../src/queues'


describe 'Redis notifier', ->
  before (done) ->
    ivy.setupQueue type: 'memory', ->
      factorialFinishedCounterObject.value = 0
      ivy.registerTask factorial, factorialFinished, name: 'factorial'

      queue.clear -> notifier.clear done

  after -> ivy.clearTasks()


  describe 'When I set up redis notifier for producer', ->
    before (done) ->
      ivy.startNotificationProducer
        type: 'redis'
        url:  process.env.REDIS_URL
      , (err) ->
        done err

    it "factorial increment hasn't been called yet", ->
      assert.equal 0, factorialFinishedCounterObject.value

    describe 'and I set it up for consumer as well', ->
      before (done) ->
        ivy.startNotificationConsumer
          type: 'redis'
          url:  process.env.REDIS_URL
        , (err) ->
          done err

      describe 'and send in the event and wait for it', ->
        before (done) ->
          ivy.once 'callerResumed', (name, args) ->
            done null

          notifier.sendTaskResult name: 'factorial', args: [null, 5]

        it 'factorial should have been called and counter incremented', ->
          assert.equal 1, factorialFinishedCounterObject.value
