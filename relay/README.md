# WanderLand relay

A tiny program that holds sealed (scrambled) friend-chat messages until the friend's
phone picks them up. It cannot read them, keeps no names or accounts, and deletes mail
after it is picked up or after 7 days.

    dart run bin/relay.dart --port 8787 --bind 127.0.0.1 --data relay-data

Limits (change them in `lib/`): 32 KB per message, 200 waiting messages per mailbox,
60 messages per mailbox per minute, 5,000 mailboxes.

See `docs/RELAY_DEPLOY.md` in the main repository for putting it on a Linux machine.
