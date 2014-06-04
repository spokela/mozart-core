#
# This file is part of Mozart
# (c) Spokela 2014
#
{IRC_COMMANDS} = require './commands'
{User, Server} = require './structs'

STATUS = {
  OK:   'OK',
  ERROR: 'NOK'
}

ERRORS = {
  MISSING_PARAMETERS: "missing parameters",

  NICKNAME_ALREADY_USED: "nickname already in use",
  NICKNAME_INVALID: "invalid nickname",

  CHANNEL_INVALID: "invalid channel",
  TARGET_INVALID: "invalid target",

  UNKNOWN_USER: "unknown user",
  UNKNOWN_TARGET: "unknown target",
  UNKNOWN_CHANNEL: "unknown channel",
  UNKNOWN_CHANNEL_MEMBER: "user not on channel",
  UNKNOWN_SERVER: "unknown server",

  USER_ALREADY_AUTHED: "user already authed",

  NOT_SUPPORTED_PROTOCOL: "invalid command (protocol)"

  UNKNOWN_COMMAND: "unknown command",
  UNKNOWN: "unknown error"
}

class Dispatcher
  constructor: (@adapter, @slot) ->

  exec: (command, args...) ->
    ######################################################
    # IRC_COMMANDS.USER_CONNECT
    #
    # Connects a fake user to the services server
    # Parameters:
    #   - nickname
    #   - ident
    #   - hostname
    #   - realname
    #   - umodes (MUST be prefixed with +)
    # Returns: user id
    #####################################################
    if command == IRC_COMMANDS.USER_CONNECT
      if args.length < 5
        return @format null, false, ERRORS.MISSING_PARAMETERS

      ts = Math.round(new Date()/1000);
      user = new User args[0], args[1], args[2], args[3], @adapter.findMyServer(), ts
      user.slot = @slot.name
      if args[4] != undefined && args[4].toString().indexOf('+') == 0
        user.changeModes args[4]
      res = @adapter.createFakeUser user
      if res != user
        return @format null, false, res

      self = @
      @slot.on 'end', (reason) ->
        user = self.adapter.findUserById(user.id)
        if user != false
          self.adapter.fakeUserQuit user, reason

      return @format user.id

    ######################################################
    # IRC_COMMANDS.USER_QUIT
    #
    # Disconnects a fake user from the services server (/quit)
    # Parameters:
    #   - id of the bot (User)
    #   - (optional) quit message
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.USER_QUIT
      if args.length < 1
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] == null
        return @format null, false, ERRORS.NOT_SUPPORTED_PROTOCOL

      u = @adapter.findUserById args[0]
      me = @adapter.findMyServer()
      if u == false || u.server.id != me.id
        return @format null, false, ERRORS.UNKNOWN_USER

      res = @adapter.fakeUserQuit u, args[1]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.USER_MODE
    #
    # Changes user modes of a user
    # Parameters:
    #   - id of the bot (User) or NULL (Server)
    #   - target nickname of target or NULL (= the bot)
    #   - modes
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.USER_MODE
      if args.length < 2 || args[2] == null
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER

      if args[1] != null && args[1].indexOf('#') == 0
        return @format null, false, ERRORS.TARGET_INVALID
      else if args[1] == null && args[0] != null
        target = u
      else
        target = @findUserByNickname(args[1])
        if !target
          return @format null, false, ERRORS.UNKNOWN_TARGET

      res = @adapter.doUmodesChange u, target, args[2]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.USER_NICKNAME
    #
    # Changes the nickname of a fake user
    # Parameters:
    #   - id of the bot (User)
    #   - new nickname
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.USER_NICKNAME
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS

      u = @adapter.findUserById args[0]
      me = @adapter.findMyServer()
      if u == false || u.server.id != me.id
        return @format null, false, ERRORS.UNKNOWN_USER
      if args[1].trim().length <= 0
        return @format null, false, ERRORS.NICKNAME_INVALID
      if @adapter.findUserByNickname(args[1]) != false
        return @format null, false, ERRORS.NICKNAME_ALREADY_USED
      res = @adapter.fakeNicknameChange u, args[1]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.USER_AWAY
    #
    # Mark the fake user as "away"
    # If no message is submitted, the fake user is marked as "back"
    # Parameters:
    #   - id of the bot (User)
    #   - (optional) away message
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.USER_AWAY
      if args.length < 1
        return @format null, false, ERRORS.MISSING_PARAMETERS

      u = @adapter.findUserById args[0]
      me = @adapter.findMyServer()
      if u == false || u.server.id != me.id
        return @format null, false, ERRORS.UNKNOWN_USER

      res = @adapter.fakeAway u, args[1]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.CHANNEL_JOIN
    #
    # Make the fake user join a channel
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.CHANNEL_JOIN
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS

      u = @adapter.findUserById args[0]
      me = @adapter.findMyServer()
      if u == false || u.server.id != me.id
        return @format null, false, ERRORS.UNKNOWN_USER
      if args[1].indexOf('#') != 0
        return @format null, false, ERRORS.CHANNEL_INVALID
      channel = @adapter.getChannelByName(args[1])
      res = @adapter.fakeChannelJoin u, channel
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.CHANNEL_PART
    #
    # Make the fake user leave a channel
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    #   - (optional) reason
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.CHANNEL_PART
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS

      u = @adapter.findUserById args[0]
      me = @adapter.findMyServer()
      if u == false || u.server.id != me.id
        return @format null, false, ERRORS.UNKNOWN_USER
      if args[1].indexOf('#') != 0
        return @format null, false, ERRORS.CHANNEL_INVALID
      channel = @adapter.getChannelByName(args[1], false)
      if !channel
        return @format null, false, ERRORS.UNKNOWN_CHANNEL
      if !channel.isUser(u)
        return @format null, false, ERRORS.UNKNOWN_CHANNEL_MEMBER
      res = @adapter.fakeChannelPart u, channel, args[2]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.CHANNEL_MODE
    #
    # Make the fake user (or the server) change modes of a channel
    # Parameters:
    #   - id of the bot (User) or NULL if SERVER_COMMANDS.CHANNEL_MODE
    #   - channel name
    #   - modes
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.CHANNEL_MODE
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER
      if args[1].indexOf('#') != 0
        return @format null, false, ERRORS.CHANNEL_INVALID
      channel = @adapter.getChannelByName(args[1], false)
      if !channel
        return @format null, false, ERRORS.UNKNOWN_CHANNEL

      res = @adapter.doChannelModeChange u, channel, args[2]
      if res != true
        return @format null, false, res

      return @format true

    ######################################################
    # IRC_COMMANDS.CHANNEL_TOPIC
    #
    # Make the fake user (or the server) change the topic of a channel
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    #   - topic
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.CHANNEL_TOPIC
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER
      if args[1].indexOf('#') != 0
        return @format null, false, ERRORS.CHANNEL_INVALID
      channel = @adapter.getChannelByName(args[1], false)
      if !channel
        return @format null, false, ERRORS.UNKNOWN_CHANNEL

      res = @adapter.fakeChannelTopicChange u, channel, args[2]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.PRIVMSG | IRC_COMMANDS.NOTICE
    #
    # Talk (privmsg or notice) to a user or channel
    # Parameters:
    #   - id of the bot (User) or NULL (Server)
    #   - target (user nickname or channel name)
    #   - message
    #   - (optional) silent (should other bots see the message?) [default = true]
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.PRIVMSG || command == IRC_COMMANDS.NOTICE || command == IRC_COMMANDS.CTCP || command == IRC_COMMANDS.CTCP_REPLY
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER

      if args[1].indexOf('#') == 0
        target = @adapter.getChannelByName(args[1], false)
        if !target
          return @format null, false, ERRORS.UNKNOWN_CHANNEL
      else
        target = @adapter.findUserByNickname(args[1])
        if !target
          return @format null, false, ERRORS.UNKNOWN_USER

      if args[3] != undefined && (args[3] == false || args[3] == 'false')
        silent = false
      else
        silent = true

      if command == IRC_COMMANDS.PRIVMSG
        res = @adapter.fakePrivmsg u, target, args[2], silent
      else if command == IRC_COMMANDS.NOTICE
        res = @adapter.fakeNotice u, target, args[2], silent
      else if command == IRC_COMMANDS.CTCP
        res = @adapter.fakePrivmsg u, target, String.fromCharCode(1) + args[2] + String.fromCharCode(1), silent
      else if command == IRC_COMMANDS.CTCP_REPLY
        res = @adapter.fakeNotice u, target, String.fromCharCode(1) + args[2] + String.fromCharCode(1), silent

      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.CHANNEL_KICK
    #
    # Make the fake user (or the server) kick someone
    # Parameters:
    #   - id of the bot (User) or NULL (Server)
    #   - channel name
    #   - target
    #   - (optional) reason
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.CHANNEL_KICK
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER

      channel = @adapter.getChannelByName(args[1], false)
      if !channel
        return @format null, false, ERRORS.UNKNOWN_CHANNEL

      target = @adapter.findUserByNickname(args[2])
      if !target
        return @format null, false, ERRORS.UNKNOWN_TARGET

      if !channel.isUser(target)
        return @format null, false, ERRORS.UNKNOWN_CHANNEL_MEMBER

      res = @adapter.doChannelKick u, channel, target, args[3]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.CHANNEL_INVITE
    #
    # Make the fake user (or the server) invite someone on a channel
    # Parameters:
    #   - id of the bot (User) or NULL (Server)
    #   - channel name
    #   - target nickname
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.CHANNEL_INVITE
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER
      if args[1].indexOf('#') != 0
        return @format null, false, ERRORS.CHANNEL_INVALID
      channel = @adapter.getChannelByName(args[1], false)
      if !channel
        return @format null, false, ERRORS.UNKNOWN_CHANNEL

      target = @adapter.findUserByNickname(args[2])
      if !target
        return @format null, false, ERRORS.UNKNOWN_TARGET

      res = @adapter.doChannelInvite u, channel, target
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.USER_KILL
    #
    # Make the fake user (or the server) kill someone
    # Parameters:
    #   - id of the bot (User) or NULL (Server)
    #   - target nickname
    #   - (optional) reason
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.USER_KILL
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER

      target = @adapter.findUserByNickname(args[1])
      if !target
        return @format null, false, ERRORS.UNKNOWN_TARGET

      res = @adapter.doUserKill u, target, args[2]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.USER_AUTH
    #
    # Make the fake user or server auth someone
    # Parameters:
    #   - id of the bot (User) or NULL (Server)
    #   - target nickname
    #   - account name
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.USER_AUTH
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER

      target = @adapter.findUserByNickname(args[1])
      if !target
        return @format null, false, ERRORS.UNKNOWN_TARGET

      res = @adapter.doUserAuth u, target, args[2]
      if res != true
        return @format null, false, res
      return @format true

    ######################################################
    # IRC_COMMANDS.USER_DEAUTH
    #
    # Make the fake user or server de-auth someone
    # Parameters:
    #   - id of the bot (User) or NULL (Server)
    #   - target nickname
    # Returns: true
    #####################################################
    else if command == IRC_COMMANDS.USER_DEAUTH
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS

      if args[0] != null
        u = @adapter.findUserById args[0]
      else
        u = @adapter.findMyServer()

      me = @adapter.findMyServer()
      if u == false || (args[0] != null && u.server.id != me.id)
        return @format null, false, ERRORS.UNKNOWN_USER

      target = @adapter.findUserByNickname(args[1])
      if !target
        return @format null, false, ERRORS.UNKNOWN_TARGET

      res = @adapter.doUserDeauth u, target
      if res != true
        return @format null, false, res
      return @format true

    return @format null, false, ERRORS.UNKNOWN_COMMAND

  format: (data = null, isOk = true, error = null) ->
    if !isOk
      if error == null
        error = ERRORS.UNKNOWN
      response = {
        status: STATUS.ERROR,
        error: error
      }
    else
      response = {
        status: STATUS.OK,
        data: data
      }
    return JSON.stringify response

module.exports = Dispatcher