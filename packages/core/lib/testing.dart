/// Helpers for widget tests and screenshot runs. Not used by app code.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads every font in the test bundle's FontManifest (the app font and
/// Material icons), so golden screenshots show real Arabic text instead of
/// the test font's boxes.
///
/// Inside this package's own tests the font is listed as `IBMPlexSansArabic`,
/// while the theme asks for `packages/alghali_core/IBMPlexSansArabic` (and
/// the apps list it that way), so each family is registered under both names.
Future<void> loadAppFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    final assets = [
      for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>())
        font['asset'] as String,
    ];
    final names = {
      name,
      if (name.startsWith('packages/')) name.split('/').last,
      if (!name.startsWith('packages/') && name != 'MaterialIcons') 'packages/alghali_core/$name',
    };
    for (final alias in names) {
      final loader = FontLoader(alias);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
  }
}

/// A Supabase client that answers from canned responses instead of the network, for
/// repository and app tests. Routes match by path prefix (`/rest/v1/rpc/checkout`,
/// `/rest/v1/orders`, `/functions/v1/booking-slots`, `/storage/v1/object/…`, `/auth/v1/…`).
class FakeServer {
  final requests = <http.Request>[];
  final _routes = <String, http.Response Function(http.Request)>{};

  /// Answers requests whose path starts with [pathPrefix]; a later route for the same
  /// prefix replaces the earlier one.
  void on(String pathPrefix, http.Response Function(http.Request) reply) =>
      _routes[pathPrefix] = reply;

  /// Every request goes nowhere, as with no connection.
  bool offline = false;

  SupabaseClient client({
    AuthClientOptions authOptions = const AuthClientOptions(autoRefreshToken: false),
  }) => SupabaseClient(
    'https://fake.supabase.co',
    'sb_publishable_fake',
    httpClient: MockClient((req) async {
      if (offline) throw http.ClientException('offline', req.url);
      requests.add(req);
      // Longest prefix wins, so `/rest/v1/rpc/x` beats `/rest/v1/`.
      final match = _routes.keys.where(req.url.path.startsWith).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      if (match.isNotEmpty) {
        // The Supabase clients read the request back off the response.
        final r = _routes[match.first]!(req);
        return http.Response.bytes(r.bodyBytes, r.statusCode, headers: r.headers, request: req);
      }
      return http.Response('{"message":"no route ${req.url.path}"}', 404, request: req);
    }),
    authOptions: authOptions,
    // No automatic retries: a test that goes offline fails at once.
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
  );

  /// The JSON body of the [i]th request.
  Map<String, dynamic> body(int i) => jsonDecode(requests[i].body) as Map<String, dynamic>;

  /// Requests to paths starting with [prefix].
  List<http.Request> to(String prefix) => [
    for (final r in requests)
      if (r.url.path.startsWith(prefix)) r,
  ];
}

http.Response jsonResponse(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// A PostgREST error as an RPC raises it (`raise exception 'CODE' using errcode = …`).
http.Response rpcError(String code, {String sqlState = 'PT409', Object? detail}) => jsonResponse(
  {
    'code': sqlState,
    'message': code,
    'details': detail == null ? null : (detail is String ? detail : jsonEncode(detail)),
    'hint': null,
  },
  switch (sqlState) {
    '42501' => 403,
    'P0002' => 404,
    '22023' => 400,
    _ => 409,
  },
);

/// The JSON body of a request the fake server received.
Map<String, dynamic> jsonBody(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;
