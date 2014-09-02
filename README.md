## Ivy

[Ivy](https://github.com/apiaryio/ivy) is [node.js](http://nodejs.org) queue library focused on easy, yet flexible task execution.

### Installation

Installation is done via NPM, by running ```npm install ivy```

### Version 2 quick example (called TODO)

```javascript

var ivy = require('ivy');

var factorial = function factorial(number, callback) {
    callback(null, 42);
}

var finished  = function resolved(result) {
    console.log('result is', result);
}


// task must be explicitly registered for now
// we'd like to change that in the future

// Also, task must be both available and registered on both client
// and producer

// ...and name must be unique globally. "package.module.submodule.function"
// pattern is highly encouraged.
ivy.registerTask(factorial, finished, {
   'name':   'testpackage.factorial',
   'queue':  'testpackage' //,
//    'route':  'testpackage.route1',
//    'priority': 0,
//    retry:    true,
//    maxRetries: 10
});

if (process.env.NODE_ENV==='producer') {

  ivy.setupQueue({
      queue: 'testpackage',

      type: 'ironmq',
      auth: {
          token:      process.env.IRONMQ_TOKEN      || 'dummy',
          project_id: process.env.IRONMQ_PROJECT_ID || 'testpackage'
      }
  });


  // optional, only if callback is registered
  ivy.startNotificationConsumer({
      'type': 'redis',
      'url':  'redis://name:password@hostname:port'
  });

  // execute task
  ivy.delayedCall(factorial, 5, function(err, result) {
    console.log("Factorial result is", result);
  });

}
elseif (process.env.NODE_ENV==='worker') {
    ivy.startNotificationProducer({
        'type': 'redis',
        'url':  'redis://name:password@hostname:port'
    });
    ivy.listen({
        queue: 'testpackage',

        type: 'ironmq',
        auth: {
            token:      process.env.IRONMQ_TOKEN   || 'dummy',
            project_id: process.env.IRONMQ_PROJECT || 'testpackage'
        },

        // optional
        messages: {
            'testpackage.factorial': {
                reserveTime: 60*60
            }
        }

    });

}

```

### Problem solved by Ivy

Ivy touches the following workflow:

* Function execution is scheduled from application ("producer") in similar way as executing function directly
* Call is serialized and transferred through queue to worker. Producer subscribes to notifier for completion
  * Worker job is considered essential. It should be thus delivered through robust, HA queue, such as AMQP, RabbitMQ, SQS, IronMQ or similar.
  * Arguments are send as a stringifyed JSON. There is no attempt to magically recover original object; called functions should thus rely only on attribute access, not method calls
* Worker executes function on shared code base, with arguments fetched from queue task
  * If execution errors, task stays in MQ or is returned there, depending on implementation
  * If it fails permanently, please beware of JSON.stringify(new Error()) idiosyncrasy
* Producer is notified back about completion
  * Speed over robustness is preferred as this should be about notifying client back, not further work
  * Thus, redis pub/sub is preferred
  * If non-notification work should follow after execution is done, it should be scheduled as another task in MQ

### Thoughts/assumptions:

* Only tasks/functions with async interface supported. Assumptions:
  * callback is last argument provided
  * callback must be present
  * first argument of callback signature is either Error or null

* Think about context change
  * Last callback is about placing task in queue as opposed to having direct callback
  * However, extracting to named function is needed 
  * Multiple callbacks looks strange.

* Explicit is better then implicit
  * In first version, use explicit task registrations
  * Leave continuation and function "backresolve" to v2
  * We can implicitly decide whether notifications are producer or consumer: consumer when `listen` is invoked, producer when first `delayedCall` is executed. Make it explicit in v1, we'll see later.

* Task registries must be same on both sides
  * "Protocol" specification for backends in other languages

* Serialization boundaries 
  * There are (mostly) no requirements on payload in queues
  * Default "protocol" is JSON, should be separated into serialization module/package
  * Protobufs should be neat choice

### Naming and definitions

There are a lot of parts and components in distributed environment. This is how `Ivy` understands them.

* **Producer**: Process that decides some task should not be processed by itself, but instead delegated to another process through queue.
* **Caller**: Particular function/code where `ivy.delayedCall` has been called.
* **Queue**: Service/process designed to dispatch messages between processes or services. It ideally processes them in (prioritized) FIFO with one time delivery. Also known as *broker*.
* **Queue name**: Inside `Queue` services, `Message`'s are organized into separate, well, queues, identified by name. To avoid naming clashes, those are always referred to as `Queue names` instead of just "queues".
* **Queue backend**: Particular piece of software implementing `Queue`'s role, i.e. `IronMQ`, `SQS`, `RabbitMQ`, ...
* **Consumer**: Process designed to consume messages from `Queue` and processing them.
* **Listener**: Part of the `Consumer` that listens to `Queue` and waits for `Message`s
* **Message**: Structured data format placed in `Queue`, understood on both ends.
* **Message serialization**: Particular serialization format used for placing `Message` into `Queue`, i.e. JSON.
* **Message format**: Particular structure used for particular `Message serialization`, i.e. `{"task": "taskname", "arguments": []}` migth be an example `Message format` for JSON `Message serialization`.
* **Task**: Function to be invoked on `Consumer`. May be parametrized by `Message`'s content.
* **Scheduled Task**: A way to describe intent of invoking `Task` at some point.
* **Task status**: A state that describes current state of `Scheduled Task` or `Task`. May be `scheduled` (successfully placed in `Queue`, but not consumed by `Consumer` yet), `running` (processing on consumer), `errored` (some state failed), `successfull` (processing done on consumer and `Notifier` successfully notified) and `done` (`successfull` + `Producer` successfully notified).
* **Task result**: Data "returned" by `Task` upon its completion with the intent of informing `Producer` about it. While the primary purpose might be computation task that produces an output that is stored in database, it is *not* considered `Task result` if it's not intended for `Producer`. Result is an array of arguments given to `Task`'s callback.
* **Task execution**: The act of running task on `Consumer`.
* **Task arguments**: Array of arguments for the `Task` *excluding* the last one (that *must* be callback. I.e. for function `factorial = (number, cb)`, the `arguments` are `[number]`, i.e. `[5]`.
* **Sending task** is an act of creating `ScheduledTask` by serializing original `delayedCall` call into `Message` and putting it in `Queue`.
* **Consuming tasks** is an act of retrieving `Messages` from `Queue` on `Consumer` done by `Listener`.
* **Caller resume**: The act of resuming the workflow back on `Producer`, done by calling callback passed to original `delayedCall`.  
* **Task resolved**: Task has been executed and `Producer` notified -- or there has been an error.
* **Notifier**: Service/process designed to inform `Producer` about `Task status` and/or `Task result`. Might be same piece of software/service as `Queue`.
* **Notification channel**: Uniquely-named "queue" used to pass `Task result`s from *any* `Consumer` to *particular* `Producer`. 
* **Notifier backend**: Particular piece of software implementing `Notifier`'s role, i.e. `IronMQ`, `Redis`, ...

### Encryption support for IronMQ

If you can encrypt all messages for better security add encryptionKey as password. We use `aes-256-cbc` algorithm for encrypt and decrypt messages.

  ivy.setupQueue({
      queue: 'testpackage',

      type: 'ironmq',
      auth: {
          token:      process.env.IRONMQ_TOKEN      || 'dummy',
          project_id: process.env.IRONMQ_PROJECT_ID || 'testpackage'
      },
      encryptionKey:  process.env.MESSAGES_ENCRYPTION_KEY
  });

## Development

## Install grunt

    npm -g install grunt-cli

## Run tests

    grunt

## Release new version using [grunt-bump](https://github.com/vojtajina/grunt-bump)

    grunt bump
    grunt bump:minor
    grunt bump:major