# Warscribe

_keeps a record of our wars_

This application is designed to accept and parse an outgoing Slack webhook.
Specifically, Warscribe takes a command like `/addwar foo vs bar` and appends `foo` and `bar` to a list of comparisons.
It's being used in [Devanooga](devanooga.com)'s [#holywars](https://devanooga.slack.com/messages/C9P3GNQ66) Slack channel.
Warscribe is built to store its data in [Airtable](airtable.com).

## Parsing

Currently, Warscribe will do one of two things when parsing a command.
It will return its version if the invoked command was `/addwar version`.
It will add two options to a list of comparisons when they are separated by `vs`, eg. `/addwar foo vs bar`.
You can provide a context for the war by appending a semicolon followed by the extra context, eg. `; baz`.
