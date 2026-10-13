import 'dart:async' show TimeoutException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// A backend call that failed, reduced to one machine [code] the UI translates.
///
/// RPCs raise UPPER_SNAKE_CASE codes such as `INVALID_PHONE` or `VERSION_CONFLICT`
/// (see docs/API.md); Auth, Storage and Edge Function errors are mapped to the same style.
/// [offline] errors are the ones the outbox retries later.
class BackendException implements Exception {
  const BackendException(this.code, {this.status, this.detail});

  factory BackendException.from(Object error) => switch (error) {
    BackendException() => error,
    PostgrestException(:final message, :final code, :final details) => BackendException(
      _isAppCode(message) ? message : _postgrestCode(code),
      status: _statusOfSqlState(code),
      detail: details?.toString(),
    ),
    AuthRetryableFetchException() => const BackendException(offlineCode),
    AuthException(:final code, :final message, :final statusCode) => BackendException(
      (code ?? (message.contains('password') ? 'weak_password' : 'auth_error')).toUpperCase(),
      status: int.tryParse(statusCode ?? ''),
    ),
    StorageException(:final message, :final statusCode) => BackendException(
      _storageCode(message, statusCode),
      status: int.tryParse(statusCode ?? ''),
    ),
    FunctionException(:final status, :final details) => BackendException(
      details is Map && details['error'] is String ? details['error'] as String : 'FUNCTION_ERROR',
      status: status,
    ),
    ClientException() || TimeoutException() => const BackendException(offlineCode),
    _ => BackendException('UNKNOWN', detail: error.toString()),
  };

  static const offlineCode = 'OFFLINE';

  final String code;
  final int? status;
  final String? detail;

  bool get offline => code == offlineCode;

  @override
  String toString() => 'BackendException($code${status == null ? '' : ', $status'})';

  static bool _isAppCode(String s) => RegExp(r'^[A-Z][A-Z0-9_]+$').hasMatch(s);

  static String _postgrestCode(String? sqlState) => switch (sqlState) {
    '42501' => 'FORBIDDEN',
    'PGRST301' || 'PGRST302' => 'SESSION_EXPIRED',
    'P0002' => 'NOT_FOUND',
    _ => 'UNKNOWN',
  };

  static int? _statusOfSqlState(String? sqlState) => switch (sqlState) {
    '42501' => 403,
    'P0002' => 404,
    'PT409' => 409,
    '22023' => 400,
    _ => null,
  };

  static String _storageCode(String message, String? status) {
    final m = message.toLowerCase();
    if (m.contains('mime') || m.contains('content type')) return 'INVALID_FILE_TYPE';
    if (status == '413' || m.contains('too large') || m.contains('size')) return 'FILE_TOO_LARGE';
    if (status == '403' || m.contains('row-level security') || m.contains('unauthorized')) {
      return 'FORBIDDEN';
    }
    if (status == '404' || m.contains('not found')) return 'NOT_FOUND';
    return 'STORAGE_ERROR';
  }
}

/// Runs [call], turning any failure into a [BackendException].
Future<T> guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on Object catch (e) {
    throw BackendException.from(e);
  }
}

const _uuid = Uuid();

/// A fresh idempotency key for one mutating call (PLAN §1 rule 5). The outbox keeps the
/// key with the queued call, so a replay after a dropped connection doesn't repeat it.
String newIdempotencyKey() => _uuid.v4();
