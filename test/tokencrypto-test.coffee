{assert} = require 'chai'

tokencrypto = require '../src/tokencrypto'

describe 'tokencrypto', ->
  it 'Nodejs 4 encrypted msg in decryptable in newer node', ->
    msg = 'Hello Crypto'
    encryptedMsg = '$aes-256-cbc$DWKO1589bRhzNrgivtoXyw=='
    pass = 'pass'

    tokencrypto.getDecrypted(encryptedMsg, pass, (err, decryptedMsg) ->
      assert.equal(msg, decryptedMsg)
    )


