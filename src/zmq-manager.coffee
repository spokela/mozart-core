#
# This file is part of Mozart
# (c) Spokela 2014
#
zmq = require 'zmq'
{EventEmitter} = require 'events'

class ZMQManager extends EventEmitter
  constructor: (@config) ->
    @slots = []
    @publisher = null
    @ready = Object.keys(config.pairs).length

  init: ->
    console.log '---------------------------------------------'

    # create publisher socket
    socket = zmq.socket 'pub'
    self = @
    socket.bind @config.publisher, (error) ->
      if error
        throw new Error "ZMQ Publisher error: #{ error }"
      else
        console.log "ZMQ Publisher ready on #{ self.config.publisher }"
        self.publisher = socket
        self.initSlots()

  initSlots: ->
    self = @
    for name, slot of @config.pairs
      socket = zmq.socket 'pair'
      socket.bind slot, (error) ->
        if error
          throw new Error "ZMQ Slot '#{ name }' error: #{ error }"
        else
          self.slots[name] = socket
          console.log "ZMQ Slot '#{ name }' ready on #{ slot }"
          self.decrReady()

  decrReady: ->
    @ready--
    if (@ready <= 0)
      @emit 'ready'

  broadcast: (eventName, args) ->
    @publisher.send "#{ eventName }% #{ @serialize(args) }"

  serialize: (args) ->
    return JSON.stringify(args)

module.exports = ZMQManager
