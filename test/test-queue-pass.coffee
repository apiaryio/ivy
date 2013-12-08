{assert}    = require 'chai'

{factorial,
 factorialSync
}           = require './testfunc'

ivy         = require '../src'

# internal
{queue}     = require '../src/queues'


describe 'Passing info through queue', ->
  before ->
    ivy.registerTask factorialSync, name: 'factorial'

  describe 'When I call delayed function on paused queue', ->
    before ->
      queue.pause()
      ivy.delayedCallSync factorialSync, 5

    describe 'and inspect paused queue', ->
      tasks = undefined

      before (done) ->
        queue.getQueueContent (err, queueTasks) ->
          tasks = queueTasks

          done err

      it 'I should see task there', ->
        assert.equal 1, tasks.length

      it 'I should see task scheduled for factorial', ->
        assert.equal 'factorial', tasks[0].name

    describe 'and when I attach consumer', ->
      before ->
        ivy.listen
          type: 'memory'

      after ->
        ivy.stopListening()


      describe 'and resume queue', ->
        before ->
          queue.resume immediatePush: true

        it 'queue should be empty', (done) ->
          queue.getQueueContent (err, queueTasks) ->
            assert.equal 0, queueTasks.length
            done err

