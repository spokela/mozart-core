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
      @slots[name] = new Slot name, bindAddr, adapter, @config.heartbeat

      @slots[name].on 'ready', ->
        console.log "ZMQ Slot '#{ name }' ready on #{ bindAddr }"

      @slots[name].on 'end', (reason) ->
        if null == reason
          reason = 'No reason provided'

        console.log "ZMQ Slot '#{ name }' ended: #{ reason }"

      @slots[name].on 'client', ->
        console.log "ZMQ Slot '#{ name }' has a client connected!"

      @slots[name].init()
      @decrReady()
    @ready = Object.keys(@slots).length

  decrReady: ->
    @ready--
    if (@ready <= 0)
      @emit 'ready'

  broadcast: (eventName, args) ->
    @publisher.send "#{ eventName }% #{ @serialize(args) }"

  serialize: (args) ->
    return JSON.stringify(args)

  end: (reason = null) ->
    for name, slot of @slots
      slot.end(reason, false)

    if @publisher != null
      @publisher.close()
      console.log 'ZMG Publisher ended.'
      @publisher = null

module.exports = ZMQManager
