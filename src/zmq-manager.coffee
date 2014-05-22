#
# This file is part of Mozart
# (c) Spokela 2014
#
zmq = require 'zmq'
{EventEmitter} = require 'events'
Slot = require './slot'

class ZMQManager extends EventEmitter
  constructor: (@config) ->
    @slots = []
    @publisher = null
    @ready = Object.keys(config.slots).length

  init: (adapter) ->
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
        self.initSlots(adapter)

  initSlots: (adapter) ->
    for name, bindAddr of @config.slots
      @slots[name] = new Slot name, bindAddr, adapter
      console.log "ZMQ Slot '#{ name }' ready on #{ bindAddr }"
      @decrReady()

  decrReady: ->
    @ready--
    if (@ready <= 0)
      @emit 'ready'

  broadcast: (eventName, args) ->
    @publisher.send "#{ eventName }% #{ @serialize(args) }"

  serialize: (args) ->
    return JSON.stringify(args)

module.exports = ZMQManager
