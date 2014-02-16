helpers = require './helpers'

if process.env.REDIS_URL
  require './integration/notifiers/redis'
else
  describe.skip 'Redis Test Suite', -> it 'Dummy it'

if ironCreds = require '../iron.json'
  process.env.IRONMQ_TOKEN      = ironCreds.token
  process.env.IRONMQ_PROJECT_ID = ironCreds.project_id

if process.env.IRONMQ_PROJECT_ID and process.env.IRONMQ_TOKEN
  require './integration/queues/ironmq'
else
  describe.skip 'IronMQ Test Suite', -> it 'Dummy it'
