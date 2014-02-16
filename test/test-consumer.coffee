{assert}    = require 'chai'

{
  factorial
  factorialSync
  factorialFinished
  factorialFinishedCounter
}           = require './helpers'

ivy         = require '../src'

# internal
{queue}     = require '../src/queues'


describe 'Consuming queue', ->

  describe 'When I set up queue with scheduled task', ->
    factorialFinishedCounter = 0

    before (done) ->
      # ivy.setupQueue
      #   type: 'memory'
      queue.clear ->
        ivy.registerTask factorial, factorialFinished, name: 'factorial'
        ivy.delayedCall factorial, 5, (err) ->
          done err


    describe 'and I configure consumer and wait for the task to complete', ->
      recievedTask   = null
      recievedResult = null

      before (done) ->
        ivy.once 'taskExecuted', (err, {name, result}) ->
          recievedTask   = name
          recievedResult = result
          done err

        ivy.listen
          type: 'memory'
        , (err) ->
          if err
            done err

      after ->
        ivy.stopListening()


      # ...because that's the job of the main app
      # after result has been passed back through notifier
      # that isn't set up here
      it 'I shouldn\'t see the counter incremented', ->
        assert.equal 0, factorialFinishedCounter

      it 'I should have recieved proper task name', ->
        assert.equal 'factorial', recievedTask

      it 'I should have recieved factorial result (5! = 120)', ->
        assert.equal 120, recievedResult

      it 'There should be no task in queue', (done) ->
        queue.getScheduledTasks (err, queueTasks) ->
          assert.equal 0, (i for i of queueTasks).length
          done err

