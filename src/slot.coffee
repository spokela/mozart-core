#
# This file is part of Mozart
# (c) Spokela 2014
#
zmq = require 'zmq'
{EventEmitter} = require 'events'
Dispatcher = require './dispatcher'

class Slot extends EventEmitter
  constructor: (@name, @bindAddr, adapter) ->
    @dispatcher = new Dispatcher adapter, @
    @socket = zmq.socket 'rep'
    @socket.bindSync @bindAddr
    self = @
    @socket.on 'message', (data) ->
      self.handle data

  handle: (data) ->
    # ignore empty messages
    if data == null || data.length <= 0
      return

    data = data.toString()
    if data.indexOf('% ') == -1
      throw new Error "Invalid message recieved on Slot '#{ @name }': #{ data }"

    split = data.split('% ')
    args =JSON.parse(split[1])
    args.unshift split[0]

    rep = @dispatcher.exec.apply(@dispatcher, args)
    console.log rep
    @socket.send rep

module.exports = Slot