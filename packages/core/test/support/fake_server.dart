import 'dart:convert';

import 'package:alghali_core/alghali_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Checks the requests the repositories send (function names and parameter names must
/// match the SQL) and how responses and errors come back, against a fake server.
class FakeServer {
  final requests = <http.Request>[];
  final _routes = <String, http.Response Function(http.Request)>{};

  /// Answers requests whose path starts with [pathPrefix].
  void on(String pathPrefix, http.Response Function(http.Request) reply) =>
      _routes[pathPrefix] = reply;

  SupabaseClient client() => SupabaseClient(
    'https://fake.supabase.co',
    'sb_publishable_fake',
    httpClient: MockClient((req) async {
      requests.add(req);
      for (final MapEntry(key: prefix, value: reply) in _routes.entries) {
        if (req.url.path.startsWith(prefix)) {
          // The Supabase clients read the request back off the response.
          final r = reply(req);
          return http.Response.bytes(r.bodyBytes, r.statusCode, headers: r.headers, request: req);
        }
      }
      return http.Response('{"message":"no route ${req.url.path}"}', 404, request: req);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Json body(int i) => jsonDecode(requests[i].body) as Json;
}

http.Response json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
