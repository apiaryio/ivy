{assert}    = require 'chai'

{
  factorial
  factorialFinished
}           = require './helpers'

ivy         = require '../src'

# internal
{queue}     = require '../src/queues'


describe 'Passing info through queue', ->

  before (done) ->
    queue.clear ->
      ivy.registerTask factorial, factorialFinished, name: 'factorial'
      done()

  describe 'When I call delayed async function on paused queue', ->
    before (done) ->
      queue.pause()
      ivy.delayedCall factorial, 5, (err) ->
        done err

    after ->
      queue.resume()

    describe 'and inspect paused queue', ->
      tasks = undefined

      before (done) ->
        queue.getScheduledTasks (err, queueTasks) ->
          tasks = queueTasks

          done err

      it 'I should see a task there', ->
        assert.equal 1, (i for i of tasks).length

      it 'I should see task scheduled for factorial', ->
        assert.equal 'factorial', JSON.parse((v for k,v of tasks)[0]).name

    describe 'and when I attach consumer', ->
      before ->
        ivy.listen
          type: 'memory'

      after ->
        ivy.stopListening()


      describe 'and resume queue', ->
        before (done) ->
          queue.once 'scheduledTaskRetrieved', ->
            process.nextTick ->
              done()

          queue.resume immediatePush: true

        it 'queue should be empty', (done) ->
          queue.getScheduledTasks (err, queueTasks) ->
            assert.equal 0, (i for i of queueTasks).length
            done err
