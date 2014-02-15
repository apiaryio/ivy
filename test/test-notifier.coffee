{assert}    = require 'chai'

{
  factorial
  factorialSync
  factorialFinished
  factorialFinishedCounterObject
}           = require './helpers'

ivy         = require '../src'

# internal
{notifier}  = require '../src/notifiers'


describe 'Notifiers', ->

  describe 'When set up notifier and pause it', ->
    before (done) ->
      factorialFinishedCounterObject.value = 0
      ivy.registerTask factorial, factorialFinished, name: 'factorial'

      ivy.startNotificationProducer type: 'memory', (err) ->
        if err then done err

        ivy.pauseNotifier (err) ->
          done err

    after (done) ->
      ivy.pauseNotifier (err) -> done err

    describe 'and I send in the task result', ->

      before (done) ->
        notifier.sendTaskResult name: 'factorial', args: [null, 5], (err) ->
          # err would be 'cannot place result into notifier'
          done err

      it "I can see it in notifier's internal storage", ->
        notifier.getNotifications (err, content) ->
          assert.equal null, err
          assert.equal 1, content.length
          assert.deepEqual [null, 5], JSON.parse(content[0]).args

      describe 'and when I start consuming notifiers', ->
        before (done) ->
          ivy.resumeNotifier immediate: true, (err) ->
            if err then return done err
            ivy.startNotificationConsumer (err) ->
              done err

        it 'factorial should have been called and counter incremented', ->
          assert.equal 1, factorialFinishedCounterObject.value

