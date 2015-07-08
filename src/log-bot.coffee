SlackClient       = require 'slack-client'
CommandProcessor  = require './command-processor'
Users             = require './users'
TriggerManager    = require './trigger-manager'
_                 = require 'underscore'
moment            = require 'moment'

###
The log bot class, responsible for human interaction
###
module.exports = class LogBot
  ###
  @param  [string]  botToken  The auth token to initialise the bot with
  ###
  constructor: (botToken) ->
    # Setup the command processor
    @cmdProcessor = new CommandProcessor
    @cmdProcessor.on 'commandSuccess', (msg) ->
      console.log "SUCCESS: #{msg}"
    @cmdProcessor.on 'commandFailed', (msg) ->
      console.log "FAILED: #{msg}"
    # Setup the trigger manager
    @triggerManager = new TriggerManager @
    # Setup the slack client
    @slack = new SlackClient botToken, true
    # Login the bot into Slack on creation
    @slack.login()
    # Whenever there is a new user to the team, create a new User type for them
    @slack.on 'userChange', =>
      @_updateUsers()
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
        @_handleDM(message) if message.getChannelType() is 'DM'
      # Checking for raw messages
      @slack.on 'raw_message', (body) =>
        # Specifically presence changes, where users have become online
        if body.type is 'presence_change' and body.presence is 'active'
          # Update the last_online field manually for this user
          @slack.users[body.user].last_online = moment().unix()

  ###
  Updates the team DB store
  ###
  _updateUsers: =>
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
  Handles a DM
  @param  [object]  message The message to parse
  ###
  _handleDM: (message, user) =>
    isAdmin = (@slack.getUserByID message.user).is_admin
    # Is a DM from an Admin?
    @cmdProcessor.parse message.text if message.user.profile.is_admin
