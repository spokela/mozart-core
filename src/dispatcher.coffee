#
# This file is part of Mozart
# (c) Spokela 2014
#
cmds = require './commands'
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

  UNKNOWN_USER: "unknown user",
  UNKNOWN_CHANNEL: "unknown channel",
  UNKNOWN_CHANNEL_MEMBER: "user not on channel",

  UNKNOWN_SERVER: "unknown server",

  UNKNOWN_COMMAND: "unknown command",
  UNKNOWN: "unknown error"
}

class Dispatcher
  constructor: (@adapter, @slot) ->

  exec: (command, args...) ->
    ######################################################
    # BOT_COMMANDS.CONNECT
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
    if command == cmds.BOT_COMMANDS.CONNECT
      if args.length < 5
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        ts = Math.round(new Date()/1000);
        user = new User args[0], args[1], args[2], args[3], @adapter.findMyServer(), ts
        user.slot = @slot.name
        if args[4] != undefined && args[4].toString().indexOf('+') == 0
          user.changeModes args[4]
        res = @adapter.createFakeUser user
        if res != user
          return @format null, false, res
        return @format user.id

    ######################################################
    # BOT_COMMANDS.DISCONNECT
    #
    # Disconnects a fake user from the services server (/quit)
    # Parameters:
    #   - id of the bot (User)
    #   - (optional) quit message
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.DISCONNECT
      if args.length < 1
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        u = @adapter.findUserById args[0]
        me = @adapter.findMyServer()
        if u == false || u.server.id != me.id
          return @format null, false, ERRORS.UNKNOWN_USER
        res = @adapter.fakeUserQuit u, args[1]
        if res != true
          return @format null, false, res
        return @format true

    ######################################################
    # BOT_COMMANDS.UMODE
    #
    # Changes user modes of a fake user
    # Parameters:
    #   - id of the bot (User)
    #   - modes
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.UMODE
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        u = @adapter.findUserById args[0]
        me = @adapter.findMyServer()
        if u == false || u.server.id != me.id
          return @format null, false, ERRORS.UNKNOWN_USER
        res = @adapter.fakeUmodesChange u, args[1]
        if res != true
          return @format null, false, res
        return @format true

    ######################################################
    # BOT_COMMANDS.NICKNAME
    #
    # Changes the nickname of a fake user
    # Parameters:
    #   - id of the bot (User)
    #   - new nickname
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.NICKNAME
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
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
    # BOT_COMMANDS.AWAY
    #
    # Mark the fake user as "away"
    # If no message is submitted, the fake user is marked as "back"
    # Parameters:
    #   - id of the bot (User)
    #   - (optional) away message
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.AWAY
      if args.length < 1
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        u = @adapter.findUserById args[0]
        me = @adapter.findMyServer()
        if u == false || u.server.id != me.id
          return @format null, false, ERRORS.UNKNOWN_USER

        res = @adapter.fakeAway u, args[1]
        if res != true
          return @format null, false, res
        return @format true

    ######################################################
    # BOT_COMMANDS.CHANNEL_JOIN
    #
    # Make the fake user join a channel
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.CHANNEL_JOIN
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
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
    # BOT_COMMANDS.CHANNEL_PART
    #
    # Make the fake user leave a channel
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    #   - (optional) reason
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.CHANNEL_PART
      if args.length < 2
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
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
    # BOT_COMMANDS.CHANNEL_MODE
    #
    # Make the fake user change modes of a channel
    # /!\ This command should NOT be used to change users modes (ovha..) because of protocol-specific features
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    #   - modes
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.CHANNEL_MODE
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        u = @adapter.findUserById args[0]
        me = @adapter.findMyServer()
        if u == false || u.server.id != me.id
          return @format null, false, ERRORS.UNKNOWN_USER
        if args[1].indexOf('#') != 0
          return @format null, false, ERRORS.CHANNEL_INVALID
        channel = @adapter.getChannelByName(args[1], false)
        if !channel
          return @format null, false, ERRORS.UNKNOWN_CHANNEL

        res = @adapter.fakeChannelModeChange u, channel, args[2]
        if res != true
          return @format null, false, res
        return @format true

    ######################################################
    # BOT_COMMANDS.CHANNEL_TOPIC
    #
    # Make the fake user change the topic of a channel
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    #   - topic
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.CHANNEL_TOPIC
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        u = @adapter.findUserById args[0]
        me = @adapter.findMyServer()
        if u == false || u.server.id != me.id
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
    # BOT_COMMANDS.CHANNEL_PRIVMSG | BOT_COMMANDS.CHANNEL_PRIVMSG
    #
    # Make the fake user talk (privmsg or notice) on a channel
    # Parameters:
    #   - id of the bot (User)
    #   - channel name
    #   - message
    #   - (optional) silent (should other bots see the message?) [default = true]
    # Returns: true
    #####################################################
    else if command == cmds.BOT_COMMANDS.CHANNEL_PRIVMSG || command == cmds.BOT_COMMANDS.CHANNEL_NOTICE
      if args.length < 3
        return @format null, false, ERRORS.MISSING_PARAMETERS
      else
        u = @adapter.findUserById args[0]
        me = @adapter.findMyServer()
        if u == false || u.server.id != me.id
          return @format null, false, ERRORS.UNKNOWN_USER
        if args[1].indexOf('#') != 0
          return @format null, false, ERRORS.CHANNEL_INVALID
        channel = @adapter.getChannelByName(args[1], false)
        if !channel
          return @format null, false, ERRORS.UNKNOWN_CHANNEL

        if args[3] != undefined && (args[3] == false || args[3] == 'false')
          silent = false
        else
          silent = true

        if command == cmds.BOT_COMMANDS.CHANNEL_PRIVMSG
          res = @adapter.fakeChannelPrivmsg u, channel, args[2], silent
        else
          res = @adapter.fakeChannelNotice u, channel, args[2], silent

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