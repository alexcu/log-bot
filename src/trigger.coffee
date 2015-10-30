{CronJob}     = require 'cron'
Users         = require './users'
Roles         = require './roles'
Logs          = require './logs'
TriggerFirer  = require './trigger-firer'
_             = require 'underscore'
moment        = require 'moment'
Q             = require 'q'

###
A trigger to invoke a log. A trigger is applied to a particular role.
###
module.exports = class Trigger
  ###
  Fires this trigger
  ###
  fire: =>
    console.info "Firing trigger #{@key}..., #{Trigger.workDay}"
    # Find all applicable roles which this trigger will run for
    Roles.all().then (roles) =>
      applicableRoles = (role for role in roles when role.trigger is @key)
      for role in applicableRoles
        # Get every user in this role
        Users.usersForRole(role.name).then (users) =>
          # Create a new conversation with this user
          for user in users
            # Check the trigger conditions
            if @triggerConditions.loggedInToday? and @triggerConditions.loggedInToday
              slackUser = @logBot.slack.getUserByID user.id
              # Last online value present?
              if slackUser.last_online?
                # We need to check the slack users as that's
                # where this info is contained
                lastOnline = slackUser.last_online
                lastOnlineToday = moment.unix(lastOnline).isSame(moment(), 'day');
                # Only perform the trigger if lastOnlineToday
                console.info "T: Trigger fired for #{@logBot.slack.getUserByID(user.id).profile.real_name}"
                new TriggerFirer @logBot, user.id, @question, @responseActions, {helpText: @helpText}, true if lastOnlineToday
            else
              new TriggerFirer @logBot, user.id, @question, @responseActions, {helpText: @helpText}, true
  ###
  @param  [LogBot]  logBot            The log bot connected to this trigger
  @param  [string]  key               The key of this trigger
  @param  [string]  question          The question to initially prompt
  @param  [string]  helpText          The help text to provided for the question
  @param  [object]  responseActions   The expected response/action pairs
  @param  [object]  triggerConditions The conditions which cause this trigger to fire
  ###
  constructor: (@logBot, @key, @question, @helpText, @responseActions, @triggerConditions) ->
    @_cronJob = new CronJob '00' + triggerConditions.time, @fire
    @_cronJob.start()