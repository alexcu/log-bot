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
  Timeouts for responding to triggers; hash contains the userId as key
  and value as timeout
  ###
  _timeouts: {}
  ###
  Performs the trigger to the given user
  @param  [string]  userId  The user id to perform the trigger on
  ###
  _performTrigger: (userId) =>
    ###
    Applies the `responseActions` to the message that was received
    @param  [object]  message   The message text received
    @param  [object]  userId    The user id who responded
    ###
    _responseActionHandler = (message, user) =>
      # Only parse expected user responses
      return if user.id isnt userId
      for regEx, action of @responseActions
        # TODO: Parse it against responseActions, ask again (recursively?) if not accepted...
        if false#text.match regEx
          console.log "Match"
          clearTimeout @_timeouts[userId]
          # Expire the timeout as the question was resolved
          return
      console.log "dont understand"
      @logBot.sendDM "Sorry I don't understand", userId
      @_performTrigger userId
    ###
    Applies the trigger expiration
    ###
    _applyExpirationHandler = =>
      # Expire that handler after six hours
      expiration = moment.duration(6, 'seconds').asMilliseconds()
      console.log "Expiration is #{expiration}ms"
      console.log _responseActionHandler
      if @_timeouts[userId]?
        console.log "Clearing timeout"
        clearTimeout @_timeouts[userId]
      @_timeouts[userId] = setTimeout (=> @logBot.sendDM "I'll ask you another time :pensive:", userId; @logBot.removeListener 'dmResponseReceived', _responseActionHandler), expiration
    # Send the question
    console.log "Asking question..."
    @logBot.sendDM @question, userId, true
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
  constructor: (@logBot, @key, @question, @responseActions, @triggerConditions) ->
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
                  @_performTrigger user.id if lastOnlineToday
              else
                @_performTrigger user.id
    @_cronJob.start()