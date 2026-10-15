import 'dart:async';
import 'dart:io';
import 'package:wanderland_relay/mail_store.dart';
import 'package:wanderland_relay/relay_server.dart';

/// Usage: relay [--port 8787] [--bind 127.0.0.1] [--data relay-data]
Future<void> main(List<String> args) async {
  String arg(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  final port = int.tryParse(arg('port', '8787')) ?? 8787;
  final bind = arg('bind', '127.0.0.1');
  final data = Directory(arg('data', 'relay-data'));
  await data.create(recursive: true);

  final store = MailStore(data);
  // --behind-proxy: trust the real address a tunnel passes along (only if the relay is not reachable directly).
  final server = RelayServer(store, trustForwardedIp: args.contains('--behind-proxy'));
  await server.start(address: InternetAddress(bind), port: port);
  stdout.writeln('WanderLand relay listening on $bind:${server.port}, mail kept in ${data.path}');

  Future<void> tidy() async {
    try {
      await store.sweep();
    } catch (_) {
      // a failed tidy-up must never stop the relay; it tries again next hour
    }
  }

  await tidy();
  Timer.periodic(const Duration(hours: 1), (_) => tidy());

  Future<void> stop(ProcessSignal _) async {
    await server.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(stop);
  try {
    ProcessSignal.sigterm.watch().listen(stop, onError: (_) {});
  } on SignalException {
    // no SIGTERM on this system
  }
}
