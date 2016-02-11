{assert}    = require 'chai'

async       = require 'async'

{
  factorial
  factorialSync
  factorialFinished
  factorialFinishedCounter
}           = require '../helpers'

ivy         = require '../../src'

# internal
{queue}     = require '../../src/queues'
{notifier}  = require '../../src/notifiers'


describe 'Test unidirectional task', ->

  describe 'When I configure Ivy for both ends', ->

    before (done) ->
      # TODO: Hmm...utility function for non-backend tests?
      async.series [
        (next) ->
          ivy.setupQueue type: 'memory', next
      , (next) ->
        queue.clear next
      , (next) ->
        ivy.listen     next
      , (next) ->
        ivy.startNotificationConsumer next
      , (next) ->
        ivy.startNotificationProducer next
      , (next) ->
        notifier.clear next
      ], done

    after ->
      ivy.stopListening()

    describe 'and register factorial task without callback', ->
      before ->
        ivy.registerTask factorial, name: 'factorial'

      describe 'and execute it and wait until it is done', ->
        notifierExecuted = false
        taskResult = undefined

        before (done) ->

          notifier.once 'taskResultSend', ->
            notifierExecuted = true


          ivy.once 'taskExecuted', (err, {name, result}) ->
            taskResult = result
            done err

          ivy.delayedCall factorial, 3, (err) ->
            if err then done err

        it 'task result should not be sent', ->
          assert.equal false, notifierExecuted

        it 'task was executed', ->
          assert.equal 6, taskResult

