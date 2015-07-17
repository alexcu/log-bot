SlackClient       = require 'slack-client'
CommandProcessor  = require './command-processor'
Users             = require './users'
TriggerManager    = require './trigger-manager'
_                 = require 'underscore'
moment            = require 'moment'
{EventEmitter}    = require 'events'

###
The log bot class, responsible for human interaction
###
module.exports = class LogBot extends EventEmitter
  ###
  This hash means that the bot is awaiting a response from the given user
  ###
  _awaitingResponse: {}
  ###
  This hash contains each of the command processors for each admin
  ###
  _commandProcessors: {}
  ###
  @param  [string]  botToken  The auth token to initialise the bot with
  ###
  constructor: (botToken) ->
    # Setup the trigger manager
    @triggerManager = new TriggerManager @
    # Setup the slack client
    @slack = new SlackClient botToken, true
    # Login the bot into Slack on creation
    @slack.login()
    # Handle slack errors
    @slack.on 'error', (err) =>
      console.log "An error has occurred : #{JSON.stringify err}"
    # Once initialised, begin listening for messages
    @slack.on 'open', =>
      console.log "#{@slack.self.name} has connected"
      # Update it anyway on creation of the bot to get first-time users
      @_updateUsers()
    # Checking for messages
    @slack.on 'message', (message) =>
      # Is a DM?
      user = @slack.getUserByID message.user
      @_handleDM(message, user) if message.getChannelType() is 'DM'
    # Checking for raw messages
    @slack.on 'raw_message', (message) =>
      # Specifically presence changes, where users have become online
      if message.type is 'presence_change' and message.presence is 'active'
        # Update the users
        @_updateUsers()
    # Whenever there is a new user to the team, create a new User
    # type for them
    @slack.on 'userChange', =>
      @_updateUsers()

  ###
  Updates the team DB store
  ###
  _updateUsers: =>
    # Update the last_online of every user to now granted they are currently online
    _.each @slack.users, (user) ->
      if user.presence is 'active'
        user.last_online = moment().unix()
    # Get all users we currently have
    Users.all().then (existingUsers) =>
      existingUserIds = _.pluck existingUsers, 'id'
      existingUserIds
      # Create each slack user who is not already created as a User type
      newUsers = _.select @slack.users, (user) ->
        isBot = user.is_bot or user.profile.real_name is 'slackbot'
        not (user.id in existingUserIds or isBot)
      # Add in the new user
      Users.add user.id, user.profile for user in newUsers

  ###
  Sends a message to the given user from the log bot as a DM
  @param  [string]  message The message to send
  @param  [string]  userId  The user id to send it to
  @param  [boolean] expectResponse Expect a human response after the DM is sent
  ###
  sendDM: (message, userId, expectResponse = false) =>
    dm = (dm for id, dm of @slack.dms when dm.user is userId)[0]
    # Open a DM if it doesn't yet exist
    unless dm?
      @slack.openDM userId, (dm) ->
        dm = @slack.dms[dm.channel.id]
        dm.send message
    else
      dm.send message
    # I expect a response from this user id
    @_awaitingResponse[userId] = expectResponse

  ###
  Handles a DM from a given user
  @param  [object]  message The message to parse
  @param  [object]  user    The slack user object
  ###
  _handleDM: (message, user) =>
    return unless message? or user?
    # Is a DM from an Admin and not awaiting a response for that user?
    if user.is_admin and not @_awaitingResponse[user.id]
      # Create a new command processor to handle this
      @_commandProcessors[user.id] = new CommandProcessor @ unless @_commandProcessors[user.id]?
      @_commandProcessors[user.id].once 'commandParsed', (data) =>
        # Send the response back to the user
        @sendDM data.message, user.id
      @_commandProcessors[user.id].parse message.text
      @emit 'adminCommandReceived', message.text, user
    # Awaiting a response? Emit a DM
    else if @_awaitingResponse[user.id]
      @emit 'dmResponseReceived', message, user
    else
      # Not awaiting a response and received a DM? Just emit it
      @emit 'dmReceived', message, user