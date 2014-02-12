{assert}    = require 'chai'

{
  factorial
  factorialSync
  factorialFinished
  factorialFinishedCounter
}           = require './testfunc'

ivy         = require '../src'

# internal
{notifier}  = require '../src/notifiers'


describe 'Notifiers', ->

  describe 'When set up notifier and pause it', ->
    
    before (done) ->
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
        notifier.getContent (err, content) ->
          assert.equal null, err
          assert.equal 1, content.length
          assert.deepEqual [null, 5], JSON.parse(content[0]).args




