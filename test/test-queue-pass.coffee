{assert}      = require 'chai'

{
  factorial
  factorialFinished
}             = require './helpers'

ivy           = require '../src'

# internal
{queue}       = require '../src/queues'
{IronMQQueue} = require '../src/queues/ironmq'


describe 'Passing info through queue', ->

  before (done) ->
    queue.setupQueue type: 'memory', -> queue.clear ->
      ivy.registerTask factorial, factorialFinished, name: 'factorial'
      done()

  after -> ivy.clearTasks()

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
        assert.equal 'factorial', (v for k,v of tasks)[0].name

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

describe 'Queue configuration', ->
  describe 'IronMQ', ->
    describe 'When I listen to IronMQ queue', ->
      before (done) ->
        ivy.listen
          type: 'ironmq'
          auth:
            token: 'dummy'
            projectId: 'dummyId'
        , done

      it 'Queue backend should be IronMQ', ->
        assert.ok queue.queue instanceof IronMQQueue



    describe 'When I try to listen to IronMQ queue without giving authentication', ->
      error = undefined

      before (done) ->
        # Client is cached, clear it up
        queue.queue.queue = null
        ivy.listen type: 'ironmq', (err) ->
          error = err
          done null

      it 'I should not be able to listen', ->
        assert.ok error instanceof Error
