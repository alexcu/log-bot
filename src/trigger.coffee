{CronJob}     = require 'cron'
Users         = require './users'
Roles         = require './roles'
_             = require 'underscore'
moment        = require 'moment'
Q             = require 'Q'
###
A trigger to invoke a log. A trigger is applied to a particular role.
###
module.exports = class Trigger
  ###
  Defines the number of hours defined in a work day. This value is loaded from a TriggerManager
  ###
  @workDay: undefined
  ###
  Timeouts for responding to triggers; hash contains the userId as key
  and value as timeout
  ###
  _timeouts: {}
  ###
  We need a semaphore to block the bot from asking multiple questions at once
  particular if the question is in response to a multi-answer response-based
  question (such as trigger 'Projects'); hash contains the userId as key
  and the semaphore as the value
  ###
  _blocks: {}
  ###
  Logs the evaluated hours for the given project (if applicable)
  @param  [string]  userId  The user to log for
  @param  [integer] hours   Hours to log
  @param  [string]  project An optional project to log
  ###
  _logHours: (hours, userId, project = null) =>
    console.log "Logging hours..."
    Users.find(userId).then (user) =>
      name = (@logBot.slack.getUserByID userId).real_name
      role = user.role
      date = moment().format("DD/MM/YYYY")
      project = project or "n/a"
      console.log "name,role,date,hours,project"
      console.log "#{name},#{role},#{date},#{hours},#{project}"
  ###
  Performs the trigger to the given user
  @param  [string]  userId  The user id to perform the trigger on
  @param  [string]  question          The question to prompt
  @param  [object]  responseActions   The expected response/action pairs
  ###
  _performTrigger: (userId, question, responseActions) =>
    ###
    Applies the `responseActions` to the message that was received
    @param  [object]  message   The message text received
    @param  [object]  userId    The user id who responded
    ###
    _responseActionHandler = (message, user) =>
      # Only parse expected user responses
      return if user.id isnt userId
      console.log "Possible response actions -> " + JSON.stringify responseActions
      for regEx, action of responseActions
        regEx = RegExp regEx, 'g'
        console.log "matching", regEx, "->", message.text.match(regEx)
        if matches = message.text.match regEx
          # Block not created? Create it
          @_blocks[userId] = require('semaphore')(1) unless @_blocks[userId]?
          # Repeat for each match
          for match, index in matches
            match = match.trim()
            do (match, index) =>
              # If action is the logging period?
              if typeof action is 'string'
                # Need to replace a workDay with the actual value it has
                action = action.replace /workDay/, Trigger.workDay
                action = action.replace /\$1/, match
                # Evaluate the mathematical expression in the action
                answer = eval action
                console.log "TODO: resolved hours to -> ", answer
                # @_logHours hours, userId, project
                # Only clear the timeout when the question is resolved
                clearTimeout @_timeouts[userId]
                @logBot.sendDM "Thank you. I have logged *#{answer} hours* for your work. :simple_smile:", userId
                # Leave a token to unblock for the next question to be asked
                @_blocks[userId].leave()
              # If action is a second set of questions
              else if typeof action is 'object'
                # Take acquisition of the asking block
                @_blocks[userId].take =>
                  # Replace $1 in question with the match
                  toAsk = action.question.replace /\$1/, match
                  @_performTrigger userId, toAsk, action.responses
          # Expire the timeout as the question was resolved
          return
      console.log "dont understand"
      @logBot.sendDM "Sorry I don't understand", userId
      @_performTrigger userId, question, responseActions
    ###
    Applies the trigger expiration
    ###
    _applyExpirationHandler = =>
      # Expire that handler after six hours
      expiration = moment.duration(6, 'hours').asMilliseconds()
      console.log "Expiration is #{expiration}ms"
      console.log _responseActionHandler
      if @_timeouts[userId]?
        console.log "Clearing timeout"
        clearTimeout @_timeouts[userId]
      @_timeouts[userId] = setTimeout (=> @logBot.sendDM "I'll ask you another time :pensive:", userId; @logBot.removeListener 'dmResponseReceived', _responseActionHandler), expiration
    # Send the question
    console.log "Asking question #{question}"
    @logBot.sendDM question, userId, true
    # Setup the expiration handler
    _applyExpirationHandler()
    console.log "setting up _responseActionHandler"
    # Add a handler for this user on a DM response which is received
    @logBot.once 'dmResponseReceived', _responseActionHandler

  ###
  @param  [LogBot]  logBot            The log bot connected to this trigger
  @param  [string]  key               The key of this trigger
  @param  [string]  question          The question to initially prompt
  @param  [object]  responseActions   The expected response/action pairs
  @param  [object]  triggerConditions The conditions which cause this trigger to fire
  ###
  constructor: (@logBot, @key, question, responseActions, triggerConditions) ->
    @_cronJob = new CronJob '00' + triggerConditions.time, =>
      console.log "Firing trigger #{@key}..."
      # Find all applicable roles which this trigger will run for
      Roles.all().then (roles) =>
        console.log "Got roles", roles
        applicableRoles = (role for role in roles when role.trigger is @key)
        console.log "Got applicable roles", applicableRoles
        for role in applicableRoles
          # Get every user in this role
          Users.usersForRole(role.name).then (users) =>
            console.log "No. users for role: ", users.length
            # Create a new conversation with this user
            for user in users
              console.log "Checking: ", user.profile.real_name, "(login conditions) -> #{triggerConditions.loggedInToday}"
              # Check the trigger conditions
              if triggerConditions.loggedInToday? and triggerConditions.loggedInToday
                slackUser = @logBot.slack.getUserByID user.id
                console.log "Need to check if logged in today... #{slackUser.last_online?}"
                # Last online value present?
                if slackUser.last_online?
                  # We need to check the slack users as that's
                  # where this info is contained
                  lastOnline = slackUser.last_online
                  lastOnlineToday = moment.unix(lastOnline).isSame(moment(), 'day');
                  console.log "Last online today -> #{lastOnlineToday}"
                  # Only perform the trigger if lastOnlineToday
                  @_performTrigger user.id, question, responseActions if lastOnlineToday
              else
                @_performTrigger user.id, question, responseActions
    @_cronJob.start()