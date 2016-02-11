{assert}    = require 'chai'
sinon       = require 'sinon'

{
  factorial
  factorialFinished
  sendObject
  sendObjectFinished
}           = require '../../helpers'

ivy         = require '../../../src'

# internal
queues     = require '../../../src/queues'

manager = queues.queue


getBaseTestSuite = (mqOptions, setupFunction, additionalTests) ->
  describe 'Integration Queue Test', ->

    before (done) ->
      manager.clear ['ivy', 'objectSendingQueue'], ->
        ivy.registerTask factorial, factorialFinished, {name: 'factorial'}
        ivy.registerTask sendObject, sendObjectFinished, {
          name: 'sendObject'
          queueName: 'objectSendingQueue'
        }

        done()

    after (done) ->
      ivy.clearTasks()
      manager.clear ['ivy', 'objectSendingQueue'], ->
        done()


    describe 'When I configure queue', ->
      before (done) ->
        setupFunction manager, done

      describe 'and send task into it', ->
        tasks = undefined

        before (done) ->
          ivy.delayedCall factorial, 5, (err) ->
            done err

        describe 'and inspect the default queue', ->
          tasks = undefined

          before (done) ->
            manager.getScheduledTasks (err, queueTasks) ->
              if err then logger.error err
              tasks = queueTasks
              done err

          it 'I should see a task there', ->
            assert.equal 1, (i for i of tasks).length

          it 'I should see task scheduled for factorial', ->
            assert.equal 'factorial', (v for k,v of tasks)[0].name

        describe 'and inspect the objectSendingQueue', ->
          tasks = undefined

          before (done) ->
            manager.getScheduledTasks {queueName: 'objectSendingQueue'}, (err, queueTasks) ->
              if err then logger.error err
              tasks = queueTasks
              done err

          it 'there should be no task', ->
            assert.equal 0, (i for i of tasks).length


      describe 'and when I send task to objectSendingQueue queue', ->

        before (done) ->
          ivy.delayedCall sendObject, {message: 'xoxo'}, (err) -> done err

        describe 'and inspect the objectSendingQueue', ->
          tasks = undefined

          before (done) ->
            manager.getScheduledTasks {queueName: 'objectSendingQueue'}, (err, queueTasks) ->
              tasks = queueTasks
              done err

          it 'there should be single task', ->
            assert.equal 1, (i for i of tasks).length

        describe 'and when I inspect the default queue', ->
          tasks = undefined

          before (done) ->
            manager.getScheduledTasks (err, queueTasks) ->
              if err then logger.error err
              tasks = queueTasks
              done err

          it 'I should still see only one task there', ->
            assert.equal 1, (i for i of tasks).length


      describe 'and when I attach consumer to the default queue', ->
        before (done) ->
          manager.once 'scheduledTaskRetrieved', ->
            process.nextTick ->
              done null

          ivy.listen mqOptions, (err) ->
            if err then done err

        after ->
          ivy.stopListening()

        it 'default queue should be empty', (done) ->
          manager.getScheduledTasks (err, queueTasks) ->
            if err then logger.error err
            assert.equal 0, (i for i of queueTasks).length
            done err

        it 'objectSendingQueue should still contain one task', (done) ->
          manager.getScheduledTasks {queueName: 'objectSendingQueue'}, (err, queueTasks) ->
            assert.equal 1, (i for i of queueTasks).length
            done err


      describe 'and when I attach consumer to the objectSendingQueue queue', ->
        before (done) ->
          manager.once 'scheduledTaskRetrieved', ->
            process.nextTick ->
              done null

          ivy.listen mqOptions, ['objectSendingQueue'], (err) ->
            if err then done err

        after ->
          ivy.stopListening()

        it 'default queue should be empty', (done) ->
          manager.getScheduledTasks (err, queueTasks) ->
            assert.equal 0, (i for i of queueTasks).length
            done err


    describe 'and try check call parameters with spy', ->
      ivySpy   = undefined
      queueSpy = undefined

      before (done) ->
        ivySpy = sinon.spy(ivy, 'delayedCall')
        queueSpy = sinon.spy(manager, 'sendTask')

        ivy.delayedCall factorial, 5, (err) ->
          done err

      after (done) ->
        ivy.delayedCall.restore()
        manager.sendTask.restore()
        done()

      it 'check arguments for delayedCall are properly JSON.stringified', ->
        assert.equal 1, ivySpy.called
        actual = JSON.stringify ivySpy.args
        assert.strictEqual actual, '[[null,5,null]]'

      it 'check arguments for sendTask', ->
        assert.equal 1, queueSpy.called
        actual =  queueSpy.args[0][0]
        expected = {
          name: "factorial"
          options: {}
          queueName: 'ivy'
          args:[5]
        }
        assert.deepEqual actual, expected

    additionalTests?()


module.exports = {
  getBaseTestSuite
}
