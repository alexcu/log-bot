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
  Performs the trigger
  ###
  _performTrigger: =>
    conversation = new Conversation @logBot, @user, @question, @responseActions
    conversation.on 'answer', (answer) ->
      # TODO: Log the hours answer!

  ###
  @param  [LogBot]  logBot            The log bot connected to this trigger
  @param  [string]  key               The key of this trigger
  @param  [string]  question          The question to initially prompt
  @param  [object]  responseActions   The expected response/action pairs
  @param  [object]  triggerConditions The conditions which cause this trigger to fire
  ###
  constructor: (@logBot, @key, @question, @responseActions, @triggerConditions) ->
    new CronJob triggerConditions.time, =>
      # Find all applicable roles which this trigger will run for
      Roles.all().then (roles) =>
        applicableRoles = _.select roles, (role) =>
          role.trigger is @key
        for role in applicableRoles
          # Get every user in this role
          Users.usersForRole(role).then (users) =>
            # Create a new conversation with this user
            for user in users
              # Check the trigger conditions
              if triggerConditions.loggedInToday? and triggerConditions.loggedInToday
                # Last online value present?
                if user.last_online?
                  lastOnline = user.last_online
                  lastOnlineToday = moment.unix(lastOnline).isSame(moment(), 'day');
                  # Only perform the trigger if lastOnlineToday
                  @_performTrigger() if lastOnlineToday
              else
                @_performTrigger()
