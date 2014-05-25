#
# This file is part of Mozart
# (c) Spokela 2014
#

IRC_EVENTS = {
# Mozart-Specific Events
  UPLINK_CONNECTED:   "irc:uplink-connected",

# Server Events
  PING:               "irc:ping",
  SERVER_ENDBURST:    "irc:server-endburst",
  SERVER_REGISTERED:  "irc:server-registered",
  SERVER_QUIT:        "irc:server-quit",

# User Events
  USER_REGISTERED:    "irc:user-registered",
  USER_QUIT:          "irc:user-quit",
  USER_NICKCHANGE:    "irc:user-nickchange",
  USER_MODESCHANGE:   "irc:user-modeschange",
  USER_AWAY:          "irc:user-away",
  USER_AUTH:          "irc:user-auth",

# Channel Events
  CHANNEL_BURST:      "irc:channel-burst",
  CHANNEL_CREATE:     "irc:channel-create",
  CHANNEL_JOIN:       "irc:channel-join",
  CHANNEL_PART:       "irc:channel-part",
  CHANNEL_EMPTY:      "irc:channel-empty",
  CHANNEL_KICK:       "irc:channel-kick",
  CHANNEL_UMODE_CHANGE:   "irc:channel-umode-change",
  CHANNEL_BAN_ADD:    "irc:channel-ban-add"
  CHANNEL_BAN_REMOVE: "irc:channel-ban-remove",
  CHANNEL_MODES_CHANGE:   "irc:channel-modes-change",
  CHANNEL_TOPIC_CHANGE:   "irc:channel-topic-change",
  CHANNEL_INVITE:         "irc:invite",
  CHANNEL_CTCP:           "irc:channel-ctcp",

  USER_PRIVMSG:       "irc:user-privmsg",
  USER_NOTICE:        "irc:user-notice",
  USER_CTCP:          "irc:user-ctcp",
  USER_CTCP_REPLY:    "irc:user-ctcp-reply",

  CHANNEL_PRIVMSG:    "irc:channel-privmsg",
  CHANNEL_NOTICE:     "irc:channel-notice",
  CHANNEL_CTCP:       "irc:channel-ctcp",
}

module.exports = IRC_EVENTS