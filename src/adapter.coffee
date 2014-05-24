#
# This file is part of Mozart
# (c) Spokela 2014
#
{EventEmitter} = require 'events'
{Channel} = require './structs'
IRC_EVENTS = require './events'

class Adapter extends EventEmitter
  constructor: (@config) ->
    @_preParsedTxt = ""
    @servers  = []
    @users    = []
    @channels = []

  init: (@socket) ->
    self = @
    @socket.on "data", (data) ->
      self.preParse new String(data)

    @socket.on "end", () ->
      console.log "socket end";

    @connect()

  preParse: (data) ->
    num = 0
    while num <= data.length
      if data.charAt(num) == "\n"
        @parse @_preParsedTxt
        @_preParsedTxt = ""
      else
        @_preParsedTxt += data.charAt(num);
      num++

  doubleDotStr: (splitted, index) ->
    next = []
    while index <= splitted.length
      next.push splitted[index];
      index++

    return next.join(' ').substr(1).trim()

  send: (line) ->

  serverSend: (msg) ->

  sendPong: (timestamp) ->

  parse: (line) ->

  handlePing: (timestamp) ->
    @emit IRC_EVENTS.PING, timestamp
    @sendPong timestamp

  serverAdd: (server) ->
    if server == false
      throw new Error 'invalid server'

    @servers[server.id] = server
    @emit IRC_EVENTS.SERVER_REGISTERED, server

  serverQuit: (server, sender, reason) ->
    if server == false
      throw new Error 'invalid server'

    @emit IRC_EVENTS.SERVER_QUIT, server, sender, reason

    for id, serv of @servers
      if serv.parent != null && serv.parent.id == server.id
        @deleteUsersFromServer(serv, reason)
        delete @servers[server.id]

    @deleteUsersFromServer(server, reason)
    delete @servers[server.id]

  userAdd: (user, silent = false) ->
    if !user || user.server == false
      throw new Error 'invalid user or server'

    user.server.users++

    @users[user.id] = user

    if !silent
      @emit IRC_EVENTS.USER_REGISTERED, user

  userQuit: (user, reason, silent = false) ->
    if !user
      throw new Error 'invalid user'

    user.server.users--
    if user.isOper()
      user.server.opers--

    for id, channelUser of user.channels
      channelUser.channel.removeUser user
      if channelUser.channel.isEmpty()
        delete @channels[channelUser.channel.id]
        if !silent
          @emit IRC_EVENTS.CHANNEL_EMPTY, channelUser.channel

    delete @users[user.id]
    if !silent
      @emit IRC_EVENTS.USER_QUIT, user, reason

  userAway: (user, reason, silent = false) ->
    if !user
      throw new Error 'invalid user'

    user.away = reason
    if !silent
      @emit IRC_EVENTS.USER_AWAY, user, reason

  userAuth: (sender, user, account) ->
    if !user
      throw new Error 'invalid user'

    user.account = account
    @emit IRC_EVENTS.USER_AUTH, user, account, sender

  nickChange: (user, newNick, silent = false) ->
    if !user
      throw new Error 'invalid user'

    user.lastNickname = user.nickname
    user.nickname = newNick

    if !silent
      @emit IRC_EVENTS.USER_NICKCHANGE, user

  endOfBurst: (server) ->
    if !server
      throw new Error 'invalid server'

    server.bursted = true;
    @emit IRC_EVENTS.SERVER_ENDBURST, server
    if server.isUplink()
      @emit IRC_EVENTS.UPLINK_CONNECTED;

  umodesChange: (sender, user, modes, silent = false) ->
    if !user || !sender
      throw new Error 'invalid sender or user'

    user.changeModes modes;

    if !silent
      @emit IRC_EVENTS.USER_MODESCHANGE, user, modes, sender

  channelAdd: (channel, burst = false, silent = false) ->
    if !channel
      throw new Error 'invalid channel'

    @channels[channel.id] = channel

    if silent
      return

    if burst
      @emit IRC_EVENTS.CHANNEL_BURST, channel
    else
      @emit IRC_EVENTS.CHANNEL_CREATE, channel

  channelJoin: (channel, user, ts, silent = false) ->
    if !channel || !user
      throw new Error 'invalid channel or user'

    channel.addUser user, "", ts

    if !silent
      @emit IRC_EVENTS.CHANNEL_JOIN, channel, user

  channelPart: (channel, user, reason, silent = false) ->
    if !channel || !user
      throw new Error 'invalid channel or user'

    channel.removeUser user
    if !silent
      @emit IRC_EVENTS.CHANNEL_PART, channel, user, reason

    if channel.isEmpty()
      delete @channels[channel.id]

      if !silent
        @emit IRC_EVENTS.CHANNEL_EMPTY, channel

  channelKick: (kicker, channel, user, reason, silent = false) ->
    if !channel || !user || !kicker
      throw new Error 'invalid channel, kicker or user'

    channel.removeUser user

    if !silent
      @emit IRC_EVENTS.CHANNEL_KICK, channel, user, kicker, reason

    if channel.isEmpty()
      delete @channels[channel.id]

      if !silent
        @emit IRC_EVENTS.CHANNEL_EMPTY, channel

  channelUsermodeChange: (sender = null, channel, user, modes, silent = false) ->
    if !channel || !user
      throw new Error 'invalid sender, channel or user'

    if !channel.isUser(user)
      return

    channel.users[user.id].changeModes(modes)

    if !silent
      @emit IRC_EVENTS.CHANNEL_UMODE_CHANGE, channel, user, sender, modes

  channelAddBan: (sender, channel, mask, ts) ->
    if !sender || !channel
      throw new Error 'invalid channel or sender'

    ban = channel.addBan mask, sender, ts
    @emit IRC_EVENTS.CHANNEL_BAN_ADD, channel, ban, sender

  channelRemoveBan: (sender, channel, mask) ->
    if !sender || !channel
      throw new Error 'invalid channel or sender'

    ban = channel.removeBan mask
    @emit IRC_EVENTS.CHANNEL_BAN_REMOVE, channel, ban, sender

  channelModesChange: (sender, channel, modes, ts, silent = false) ->
    if !sender || !channel
      throw new Error 'invalid channel or sender'

    # don't do nothing here because of protocol-specific modes
    if !silent
      @emit IRC_EVENTS.CHANNEL_MODES_CHANGE, channel, modes, sender, ts

  channelTopicChange: (sender, channel, topic, ts, silent = false) ->
    if !sender || !channel
      throw new Error 'invalid channel or sender'

    if topic.length <= 0
      topic = null

    channel.topic = topic
    channel.topicTs = ts

    if !silent
      @emit IRC_EVENTS.CHANNEL_TOPIC_CHANGE, channel, topic, sender, ts

  channelInvite: (sender, channel, target, silent = false) ->
    if !sender || !target || !channel
      throw new Error 'invalid channel, sender or target'

    if !silent
      @emit IRC_EVENTS.CHANNEL_INVITE, channel, sender, target

  privmsg: (sender, target, msg, secure, silent = false) ->
    # don't handle empty msgs
    if !msg || msg.trim().length == 0
      return

    if !silent  && target instanceof Channel
      @emit IRC_EVENTS.CHANNEL_PRIVMSG, sender, target, msg, secure
      @emit "#{ IRC_EVENTS.CHANNEL_PRIVMSG }@#{ target.name }", sender, target, msg, secure
    else
      @emit IRC_EVENTS.USER_PRIVMSG, sender, target, msg, secure
      @emit "#{ IRC_EVENTS.USER_PRIVMSG }@#{ target.id }", sender, target, msg, secure

  notice: (sender, target, msg, secure, silent = false) ->
    # don't handle empty msgs
    if !msg || msg.trim().length == 0
      return

    if !silent && target instanceof Channel
      @emit IRC_EVENTS.CHANNEL_NOTICE, sender, target, msg, secure
      @emit "#{ IRC_EVENTS.CHANNEL_NOTICE }@#{ target.name }", sender, target, msg, secure
    else
      @emit IRC_EVENTS.USER_NOTICE, sender, target, msg, secure
      @emit "#{ IRC_EVENTS.USER_NOTICE }@#{ target.id }", sender, target, msg, secure

  disconnect: ->

  findUserByNickname: (nickname) ->
    for id, user of @users
      if user.nickname.toLowerCase() == nickname.toLowerCase()
        return user
    return false

  findUserById: (id) ->
    if @users[id] != undefined
      return @users[id]
    return false

  findServerByName: (serverName) ->
    for id, server of @servers
      if server.name == serverName
        return server
    return false

  deleteUsersFromServer: (server, reason) ->
    for id, user of @users
      if user.server != undefined && user.server.id == server.id
        @userQuit user, reason

  findMyServer: ->
    for id, server of @servers
      if server.hops == 0
        return server
    return false

  getChannelByName: (name, create = true) ->
    for id, channel of @channels
      if channel.name.toLowerCase() == name.toLowerCase()
        return channel
    if create
      return new Channel name
    else
      return false

  emit: (eventName, args...) ->
    super('zmq', eventName, args)
    args.unshift eventName
    super args

  # COMMANDS
  createFakeUser: (user) ->
    @userAdd(user, true)
    return user

  fakeUserQuit: (user, reason) ->
    @userQuit(user,  reason, true)
    return true

  doUmodesChange: (sender, user, modes) ->
    @umodesChange(user, user, modes, true)
    return true

  fakeNicknameChange: (user, newnick) ->
    @nickChange(user, newnick, true)
    return true

  fakeAway: (user, reason) ->
    @userAway(user, reason, true)
    return true

  fakeChannelJoin: (user, channel, created = false) ->
    if created
      @channelAdd(channel, false, true)
    @channelJoin(channel, user, Math.round(new Date()/1000), true)
    if created
      @channelUsermodeChange(null, channel, user, "+o", true)
    return true

  fakeChannelPart: (user, channel, reason = null) ->
    @channelPart(channel, user, reason, true)
    return true

  doChannelModeChange: (sender, channel, modes) ->
    ts = Math.round(new Date()/1000)
    @channelModesChange(sender, channel, modes, ts, true)
    return true

  fakeChannelTopicChange: (sender, channel, topic) ->
    @channelTopicChange(sender, channel, topic, Math.round(new Date()/1000), true)
    return true

  fakePrivmsg: (sender, target, msg, silent = true) ->
    @privmsg(sender, target, msg, false, silent)
    return true

  fakeNotice: (sender, target, msg, silent = true) ->
    @notice(sender, target, msg, false, silent)
    return true

  doChannelKick: (sender, channel, target, reason) ->
    @channelKick(sender, channel, target, reason, true)
    return true

  doChannelInvite: (sender, channel, target) ->
    @channelInvite(sender, channel, target, true)
    return true

module.exports = Adapter