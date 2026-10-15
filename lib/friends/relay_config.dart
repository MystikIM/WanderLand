/// Where the mailbox relay lives. Override at build time with
/// `--dart-define=RELAY_URL=https://your.relay.example/`.
const String kRelayUrl = String.fromEnvironment('RELAY_URL', defaultValue: 'https://chat.mystikim.com');
