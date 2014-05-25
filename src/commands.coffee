#
# This file is part of Mozart
# (c) Spokela 2014

IRC_COMMANDS = {
  CHANNEL_JOIN:         'irc:chan-join',
  CHANNEL_PART:         'irc:chan-part',
  CHANNEL_MODE:         'irc:chan-mode',
  CHANNEL_TOPIC:        'irc:chan-topic',
  CHANNEL_KICK:         'irc:chan-kick',
  CHANNEL_INVITE:       'irc:chan-invite',

  USER_AWAY:            'irc:away',
  USER_CONNECT:         'irc:connect',
  USER_QUIT:            'irc:disconnect',
  USER_MODE:            'irc:umode',
  USER_NICKNAME:        'irc:nickname',
  USER_KILL:            'irc:user-kill',
  USER_AUTH:            'irc:user-auth',
  USER_DEAUTH:          'irc:user-deauth',

  PRIVMSG:              'irc:privmsg',
  NOTICE:               'irc:notice',
  CTCP:                 'irc:ctcp',
  CTCP_REPLY:           'irc:ctcp-reply',

  SERVER_QUIT:          'irc:squit',
  SERVER_JUPE_ADD:      'server:jupe-add',
  SERVER_JUPE_REMOVE:   'server:jupe-remove'
  WALLOPS:              'irc:wallops',

  NETWORK_BAN:          'irc:ban'
}

MOZART_COMMANDS = {
  DB_GETINFOS:          'mz:db:getinfos',

  DB_UPDATE_USER:       'mz:db:user-update',
  DB_UPDATE_SERVER:     'mz:db:server-update',
  DB_UPDATE_CHANNEL:    'mz:db:channel-update',
  DB_UPDATE_CHAN_USER:  'mz:db:chan-user-update',
  DB_UPDATE_CHAN_BAN:   'mz:db:chan-ban-update'
}

module.exports = {IRC_COMMANDS, MOZART_COMMANDS}