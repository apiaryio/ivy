{assert}    = require 'chai'

{
  factorial
  factorialFinished
}           = require '../../helpers'

ivy         = require '../../../src'

# internal
{queue}     = require '../../../src/queues'


describe 'IronMQ Queue Backend Test', ->
  mqOptions = 
    type: 'ironmq'
    auth:
      token:      process.env.IRONMQ_TOKEN
      projectId:  process.env.IRONMQ_PROJECT_ID

  before (done) ->
    queue.clear ->
      ivy.registerTask factorial, factorialFinished, name: 'factorial'
      done()

  describe 'When I configure queue', ->
    before (done) ->
      ivy.setupQueue mqOptions, (err) ->
        if err then return err
        queue.clear (err) ->
          # err means queue does not exists and that's OK
          done null

    describe 'and send task into it', ->
      tasks = undefined

      before (done) ->
        ivy.delayedCall factorial, 5, (err) ->
          done err

      describe 'and inspect the queue', ->
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
      before (done) ->
        queue.once 'scheduledTaskRetrieved', ->
          process.nextTick ->
            done null

        ivy.listen mqOptions, (err) ->
          if err then done err

      after ->
        ivy.stopListening()

      it 'queue should be empty', (done) ->
        queue.getScheduledTasks (err, queueTasks) ->
          assert.equal 0, (i for i of queueTasks).length
          done err