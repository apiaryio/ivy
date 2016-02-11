helpers = require './helpers'

# non-conditional first
require './integration/test-task-without-publisher-callback'
require './integration/queues/memory'

if process.env.IRONMQ_CONSUME_INTERVAL
  console.error "Warning: you have set IRONMQ_CONSUME_INTERVAL to #{process.env.IRONMQ_CONSUME_INTERVAL} some test can't work."

if process.env.REDIS_URL
  require './integration/notifiers/redis'
else
  describe.skip 'Redis Test Suite', -> it 'Dummy it'

process.env.IRONMQ_TOKEN = 'DPUHV1ah8D1vetwV1UA_8LjH32U'
process.env.IRONMQ_PROJECT_ID = '53e34de67cdb920009000054'

try
  if ironCreds = require '../iron.json'
    process.env.IRONMQ_TOKEN      = ironCreds.token
    process.env.IRONMQ_PROJECT_ID = ironCreds.project_id
catch err
  # not loading credentials

if process.env.IRONMQ_PROJECT_ID and process.env.IRONMQ_TOKEN
  require './integration/queues/ironmq'
else
  describe.skip 'IronMQ Test Suite', -> it 'Dummy it'
