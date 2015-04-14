{assert}    = require 'chai'
sinon       = require 'sinon'

{
  factorial
  factorialFinished
  sendObject
  sendObjectFinished
}           = require '../../helpers'
{
  getBaseTestSuite
}           = require './base'

ivy         = require '../../../src'

# internal
{queue}     = require '../../../src/queues'


describe 'IronMQ Queue Backend Test', ->

  mqOptions =
    type: 'ironmq'
    auth:
      token:      process.env.IRONMQ_TOKEN
      projectId:  process.env.IRONMQ_PROJECT_ID
    encryptionKey: 'XXXX'

  getBaseTestSuite mqOptions, (queue, done) ->
    ivy.setupQueue mqOptions, (err) ->
      if err then return err
      queue.clear ['ivy', 'objectSendingQueue'], (err) ->
        # err means queue does not exists and that's OK
        done null
