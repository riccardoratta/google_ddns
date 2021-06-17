import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final log = Logger.root;
final sink = File('google_ddns.log').openWrite(mode: FileMode.append);

void main(List<String> args) async {
  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((record) {
    final message = '${record.level.name}: ${record.time}: ${record.message}';
    print(message);
    sink.writeln(message);
  });

  final options = (ArgParser()
        ..addOption('hostname', abbr: 'h', mandatory: true)
        ..addOption('username', abbr: 'u', mandatory: true)
        ..addOption('password', abbr: 'p', mandatory: true))
      .parse(args);

  final ifconfig = await http.get(Uri.https('ifconfig.me', '/ip'));
  if (ifconfig.statusCode == 200) {
    final last = File('last.ip');
    final public = InternetAddress(ifconfig.body);
    if (await last.exists()) {
      try {
        if (InternetAddress(await last.readAsString()) == public) {
          log.fine('record already up to date');
          return;
        }
      } on ArgumentError catch (_) {
        log.warning('couldn\'t parse internet address in "last.ip" file');
      }
    } else {
      try {
        await last.create();
      } on FileSystemException catch (e) {
        log.severe('unable to create "last.ip" file');
      }
    }

    final domainsGoogle = await http.post(
        Uri.https('domains.google.com', '/nic/update',
            {'hostname': options['hostname'], 'myip': public.address}),
        headers: {
          'Authorization':
              'Basic ' + base64Encode(utf8.encode("${options['username']}:${options['password']}"))
        });

    if (domainsGoogle.statusCode == 200) {
      final response = domainsGoogle.body.substring(0, 4);
      if ((response == 'good') | (response == 'noch')) {
        await last.writeAsString(public.address);
      }
      switch (response) {
        case 'good':
          log.fine('domain updated to ${public.address}');
          break;
        case 'noch':
          log.warning('record already up to date for Google domains');
          break;
        case 'badauth':
          log.severe('bad authentication credentials');
          break;
        default:
          log.severe('unknown Google domains response: "${domainsGoogle.body.trim()}');
      }
    } else {
      log.severe('not OK Google domains status (${domainsGoogle.statusCode})');
    }
  } else {
    log.severe('not OK ifconfig status (${ifconfig.statusCode})');
  }
}
