# LogBot

LogBot is a [Slack](http://slack.com/) bot integration designed to effortlessly capture a log of productivity in your Slack team.

Slack administrators assign members various roles, such as `Staff` or `Intern`, and each role can be assign a trigger. A trigger describes a series of questions that LogBot asks users, and which human responses are acceptable, and what is calculated to be logged for productivity hours.

When the conditions are true (e.g., "every Friday at 4pm", "every day at 3pm granted users have logged in at least once during the day"), LogBot asks each user associated to the role a simple question (as described by the trigger) and captures the output of the user.

Administrators can then query LogBot of the logs for certain users or roles, and then assess the productivity of those users based on what the user has logged. LogBot returns back a CSV of data via a temporary one-click URL.

# Getting Started

## Installing

1. Begin by installing Node.js on your system. You can download Node.js [here](http://nodejs.org/).
2. Install dependencies by running `npm install`
3. Start LogBot by running `npm start`.

## Setting `config.json`

A configuration file for LogBot settings is needed, `config.json`. Place this file in the `log-bot` root directory. Here's a sample:

```
{
  "botToken": "xoxb-xxxxxxx-xxxxxxxxxxxx",
  "triggerFile" : "triggers.json",
  "datastoreDirectory" : "res",
  "server" : {
    "ip" : "xxx.xxx.xxx.xxx",
    "port" : 3000
  }
}
```

- `botToken` Your auth token for the bot you have [created](https://slack.com/services/new/bot) on Slack
- `triggerFile` Where your [trigger file](#triggers) is located. Can be an absolute path, otherwise is it relative to the `log-bot` root directory. If you want to place this file alongside that of `config.json`, then just leave this as `triggers.json`
- `datastoreDirectory` A relative or absolute path for where LogBot can store data.
- `server` The server `ip` and `port` which LogBot hosts its data server from the machine it is run on.

## [Creating triggers](id:triggers)

A trigger configuration describes possible triggers. The JSON file can be commented with `//` comments inside this JSON file to help keep your file organised.

There is a commented example `triggers.json` that you can read through and model your own triggers from.

There are two required root fields in the trigger file:

- `workDay` A number to describe the typical working hours expected in your team in a working day.
- `triggers` An object containing keys for each of your various triggers.

Each key inside the `triggers` object is the unique name of that trigger. A trigger's unique name can **only contain alphanumeric, spaces, dashes and underscore characters**. A trigger will typically contain four keys:

- `question` The initial question to prompt to the user when the trigger is fired.
- `helpText` An optional help text, usually to provide help on which answers are acceptable for the question asked
- `responses` An object containing response/action [bindings](#response-actions) (see below)
- `conditions` [Conditions](#conditions) which the fire trigger

### [Responses/Actions bindings](id:response-actions)

Inside the `responses` object should contain key/value bindings to **regular expressions** (key) and the appropriate **action** (value) LogBot takes when the regular expression is matched against user responses.

If the action is a **string**, it should represent either a mathematical expression that will return the number of hours to log, or signal LogBot to reask the question. You can use `workDay` in the expression calculated, `$1` to use the answer the user has entered captured by the regular expression, or `$!` to make LogBot re-ask the trigger from its initial question. For example:

```
"\d"    : "$1",				// Use the integer captured by the regular expression
							// "\d" for the hours logged

"yes|y" : "5 * workDay",	// Where the user responds "yes" or "y", use five
							// mulitplied by one workDay for the hours logged

"no|n"  : "$!"				// Where the user responds "no" or "n", ask the
							// question again
```

If the action is an **object**, then a follow-up question is asked, each with its own `question`, `helpText` and `responses` keys/values. Note that LogBot will keep asking questions until the question is resolved to a string-based action (i.e., to a concrete hour duration it can use to log the hours worked).


### [Trigger conditions](id:conditions)

At present, two conditions are currently supported:

- `time`, a [cron-formatted](https://en.wikipedia.org/wiki/Cron#Configuration_file) time value for when the trigger is fired.
- `loggedInToday`, resolving to either `true` or `false`, to check whether the user the trigger is being applied to has signed in to Slack _at least once_.

The `time` **is mandatory** and should be present in every trigger you write.

# Using LogBot

## As an administrator

As a Slack administrator user, you will have the ability to create new roles, assign other Slack users to roles, and assign roles various triggers, using an SQL-esque DSL. Admin users can interact with LogBot by issuing these commands via sending it an IM.

Note that when communicating with LogBot, Role and Trigger names _must_ be encapsulated with double quotes. Users _must_ be referenced using Slack's `@someone` syntax.

Note that when creating roles, a role name can **only contain alphanumeric, spaces, dashes and underscore characters**.

Use the `HELP` command to see what LogBot knows.

### Role Commands

- `ADD ROLE "Intern Staff"` Creates a new role named "Intern Staff"
- `ASSIGN @freddy ROLE "Intern Staff"` Assigns the user who's tag is `@freddy` the newly created role "Intern Staff"
- `GET ROLES FOR @freddy, @frankey, @jerry` Gets roles for `@freddy`, `@frankey` and `@jerry`
- `DROP ROLE "Intern Staff"` Will remove the `Intern Staff` role, and in this case `@freddy` will be unassigned his role
- `GET ALL ROLES` Get every role that LogBot knows of

### Log Commands

- `GET LOG FOR @freddy` Will generate the download link for `@freddy`'s logs
- `GET LOGS FOR "Intern Staff", "Full Time Staff"` Will generate the download link for these roles
- `GET ALL LOGS` Will generate the download link for every log available

### Trigger Commands

- `GET ALL TRIGGERS` Get every trigger that is available
- `GET TRIGGER FOR "Intern Staff"` Will return the triggers associated to the role `Intern Staff`
- `FIRE ALL TRIGGERS NOW` Will fire every trigger registered right now, regardless of when they're _supposed_ to be triggered

## As a non-administrator

As a standard Slack user, your interaction with LogBot is very limited. Like Slackbot, LogBot will ignore what you say. The only time LogBot will listen to you is when a trigger fires and asks you a question, of which you have _at least_ **six hours** to respond.

