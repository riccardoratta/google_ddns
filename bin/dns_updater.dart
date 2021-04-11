import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

final username = 'xRcpBcgypsXSTcyp';
final password = 'pH4c3t6uQbxsQ28S';

void main(List<String> arguments) async {
  try {
    final myip = await http.get(Uri.https('ifconfig.me', '/ip'));
    if (myip.statusCode == 200) {
      final response = await http.post(
          Uri.https('domains.google.com', '/nic/update',
              {'hostname': 'hstead.app', 'myip': myip.body}),
          headers: {
            'Authorization':
                'Basic ' + base64Encode(utf8.encode('$username:$password'))
          });
      if (response.statusCode == 200) {
        switch (response.body.substring(0, 4)) {
          case 'good':
            await mail('DNS Updated',
                'Successfully updated DNS record to ${myip.body}}');
            break;
          case 'noch':
            print('DNS record already up to date');
            break;
          default:
            await mail('DNS Updated',
                'Unknown Google Domains response: "${response.body}"');
        }
      } else {
        debugRequest(response);
      }
    } else {
      debugRequest(myip);
    }
  } catch (e) {
    rethrow;
  }
}

void debugRequest(http.Response response) {
  print(
      'Invalid response for request "${response.request}" (${response.statusCode})}' +
          (response.contentLength != 0 ? '\nbody: "${response.body}"' : ''));
}

Future<void> mail(String subject, String message) async {
  print('$subject\t$message');
  await ((await Process.start('sendmail', ['riccardoratta@gmail.com'])).stdin
        ..write('Subject: $subject\n$message\n.\n'))
      .flush();
}
