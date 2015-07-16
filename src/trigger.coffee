{CronJob}     = require 'cron'
Users         = require './users'
Roles         = require './roles'
Logs          = require './logs'
_             = require 'underscore'
moment        = require 'moment'
Q             = require 'q'
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
  Performs the trigger to the given user
  @param  [string]  userId            The user id to perform the trigger on
  @param  [string]  question          The question to prompt
  @param  [object]  responseActions   The expected response/action pairs
  @param  [object]  extraParams       Extra parameters to provide to the trigger, optional
  ###
  _performTrigger: (userId, question, responseActions, extraParams) =>
    ###
    Applies the `responseActions` to the message that was received
    @param  [object]  message   The message text received
    @param  [object]  userId    The user id who responded
    ###
    _responseActionHandler = (message, user) =>
      # Only parse expected user responses
      return if user.id isnt userId
      for regEx, action of responseActions
        regEx = RegExp regEx, 'g'
        if matches = message.text.match regEx
          # Block not created? Create it
          @_blocks[userId] = require('semaphore')(1) unless @_blocks[userId]?
          # Repeat for each match
          for match, index in matches
            match = match.trim()
            do (match, index) =>
              # If action is the logging period?
              if typeof action is 'string'
                # If we have encountered a $! action, then restart
                # from initial questions and responses
                if action is "$!"
                  @_performTrigger userId, @question, @responseActions, {helpText: @helpText}
                else
                  # Need to replace a workDay with the actual value it has
                  action = action.replace /workDay/, Trigger.workDay
                  action = action.replace /\$1/, match
                  # Evaluate the mathematical expression in the action
                  hours = parseFloat(eval action)
                  project = (if extraParams? then extraParams.previousMatch)
                  # Actually insert the log!
                  Logs.insert userId, hours, project
                  # Only clear the timeout when the question is resolved
                  clearTimeout @_timeouts[userId]
                  @logBot.sendDM "Thank you. I have logged *#{hours.toFixed(2)} hours* for #{if project? then "_" + project + "_" else "your work"}. :simple_smile:", userId
                # Leave a token to unblock for the next question to be asked,
                # granted it isn't the last question
                @_blocks[userId].leave() if @_blocks[userId].current isnt 0
              # If action is a second set of questions
              else if typeof action is 'object'
                # Take acquisition of the asking block
                @_blocks[userId].take =>
                  # Replace $1 in question with the match
                  toAsk = action.question.replace /\$1/, match
                  # See if there was a dollar one match, and if so we will provide a previousMatch
                  previousMatch = if action.question.match(/\$1/)? then match
                  @_performTrigger userId, toAsk, action.responses, { previousMatch: previousMatch, helpText: action.helpText }
          # Expire the timeout as the question was resolved
          return
      @logBot.sendDM "Sorry I don't understand", userId
      @_performTrigger userId, question, responseActions, if extraParams? then extraParams
    ###
    Applies the trigger expiration
    ###
    _applyExpirationHandler = =>
      # Expire that handler after six hours
      expiration = moment.duration(6, 'hours').asMilliseconds()
      if @_timeouts[userId]?
        clearTimeout @_timeouts[userId]
      timeoutFn = =>
        # Remove the listener for any more responses
        @logBot.sendDM "I'll ask you another time :pensive:", userId
        @logBot.removeListener 'dmResponseReceived', _responseActionHandler
        # Delete the block we were waiting for
        delete @_blocks[userId]
      @_timeouts[userId] = setTimeout timeoutFn, expiration
    # Send the question (with helpText if applicable)
    messageToSend = if extraParams.helpText? then "#{question}\n>_#{extraParams.helpText}_" else question
    @logBot.sendDM messageToSend, userId, true
    # Setup the expiration handler
    _applyExpirationHandler()
    # Add a handler for this user on a DM response which is received
    @logBot.once 'dmResponseReceived', _responseActionHandler

  ###
  @param  [LogBot]  logBot            The log bot connected to this trigger
  @param  [string]  key               The key of this trigger
  @param  [string]  question          The question to initially prompt
  @param  [string]  helpText          The help text to provided for the question
  @param  [object]  responseActions   The expected response/action pairs
  @param  [object]  triggerConditions The conditions which cause this trigger to fire
  ###
  constructor: (@logBot, @key, @question, @helpText, @responseActions, triggerConditions) ->
    @_cronJob = new CronJob '00' + triggerConditions.time, =>
      # Find all applicable roles which this trigger will run for
      Roles.all().then (roles) =>
        applicableRoles = (role for role in roles when role.trigger is @key)
        for role in applicableRoles
          # Get every user in this role
          Users.usersForRole(role.name).then (users) =>
            # Create a new conversation with this user
            for user in users
              # Check the trigger conditions
              if triggerConditions.loggedInToday? and triggerConditions.loggedInToday
                slackUser = @logBot.slack.getUserByID user.id
                # Last online value present?
                if slackUser.last_online?
                  # We need to check the slack users as that's
                  # where this info is contained
                  lastOnline = slackUser.last_online
                  lastOnlineToday = moment.unix(lastOnline).isSame(moment(), 'day');
                  # Only perform the trigger if lastOnlineToday
                  @_performTrigger user.id, @question, @responseActions, {helpText: @helpText} if lastOnlineToday
              else
                @_performTrigger user.id, @question, @responseActions, {helpText: @helpText}
    @_cronJob.start()