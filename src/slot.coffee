#
# This file is part of Mozart
# (c) Spokela 2014
#
zmq = require 'zmq'
{EventEmitter} = require 'events'

class Slot extends EventEmitter
  constructor: (@name, @bindAddr) ->
    @socket = zmq.socket 'rep'
    @socket.bindSync @bindAddr
    self = @
    @socket.on 'message', (data) ->
      self.handle data

  handle: (data) ->
    console.log "Slot '#{ @name }' message: #{ data }"
    @socket.send('OK')

module.exports = Slot