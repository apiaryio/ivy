{assert}    = require 'chai'
sinon       = require 'sinon'

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

  after -> ivy.clearTasks()


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

  describe 'and try check call paramenters with spy', ->
    ivySpy = undefined
    queueSpy = undefined

    before (done) ->
      ivySpy = sinon.spy(ivy, 'delayedCall')
      queueSpy = sinon.spy(queue, 'sendTask')

      ivy.delayedCall factorial, 5, (err) ->
        done err

    it 'check arguments for delayedCall', ->
      assert.equal 1, ivySpy.called
      actual = JSON.stringify ivySpy.args
      assert.equal actual, '[[null,5,null]]'

    it 'check arguments for sendTask', ->
      assert.equal 1, queueSpy.called
      actual =  JSON.stringify queueSpy.args[0][0]
      expected = '{"name":"factorial","options":{},"args":[5]}'
      assert.equal actual, expected
