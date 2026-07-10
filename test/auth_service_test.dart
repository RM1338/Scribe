import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scribe/services/auth_service.dart';

AuthService _serviceReturning(String body, {int status = 200, List<Uri>? hits}) {
  return AuthService(
    httpClient: MockClient((request) async {
      hits?.add(request.url);
      return http.Response(body, status);
    }),
  );
}

void main() {
  setUp(() {
    dotenv.loadFromString(envString: '''
SUPABASE_URL=https://example.supabase.co
SUPABASE_ANON_KEY=test-anon-key
''');
  });

  group('isEmailConfirmationRequired', () {
    test('is false when the project auto-confirms emails', () async {
      final service = _serviceReturning('{"mailer_autoconfirm": true}');
      expect(await service.isEmailConfirmationRequired(), isFalse);
    });

    test('is true when the project requires confirmation', () async {
      final service = _serviceReturning('{"mailer_autoconfirm": false}');
      expect(await service.isEmailConfirmationRequired(), isTrue);
    });

    test('treats a missing flag as requiring confirmation', () async {
      // Fail safe: an unrecognised payload must not read as "auto-confirm on",
      // which would be the permissive interpretation.
      final service = _serviceReturning('{"disable_signup": false}');
      expect(await service.isEmailConfirmationRequired(), isTrue);
    });

    test('throws rather than guessing when the probe fails', () async {
      final service = _serviceReturning('nope', status: 500);
      expect(
        () => service.isEmailConfirmationRequired(),
        throwsA(isA<AuthConfigException>()),
      );
    });

    test('probes the auth settings endpoint once and caches it', () async {
      final hits = <Uri>[];
      final service = _serviceReturning('{"mailer_autoconfirm": false}', hits: hits);

      await service.isEmailConfirmationRequired();
      await service.isEmailConfirmationRequired();
      await service.isEmailConfirmationRequired();

      expect(hits, hasLength(1));
      expect(hits.single.path, '/auth/v1/settings');
    });
  });
}
