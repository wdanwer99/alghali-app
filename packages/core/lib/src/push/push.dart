import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_env.dart';

/// An alert as push delivers it: the dispatcher's `code` plus the payload values
/// (all strings), e.g. `{code: ORDER_READY, order_id: …, ref: …}`, and the wording the
/// server sent in the reader's language as `_title` / `_body` when there is one.
typedef PushData = Map<String, String>;

/// What the apps need from Firebase Cloud Messaging (D-109). Builds without Firebase
/// settings, and tests, use [NoPush].
abstract class PushClient {
  /// This phone's FCM token; null when push isn't available.
  Future<String?> token();

  Stream<String> get tokenRefresh;

  /// Alerts that arrive while the app is open (Android shows nothing by itself then).
  Stream<PushData> get foreground;

  /// Taps on an alert in the notification tray, while the app was in the background.
  Stream<PushData> get taps;

  /// The alert whose tap started the app, if any.
  Future<PushData?> initialTap();

  /// Asks for the notification permission (Android 13+). True when allowed.
  Future<bool> requestPermission();
}

class NoPush implements PushClient {
  const NoPush();

  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<PushData> get foreground => const Stream.empty();
  @override
  Stream<PushData> get taps => const Stream.empty();
  @override
  Future<PushData?> initialTap() async => null;
  @override
  Future<bool> requestPermission() async => false;
}

class FirebasePush implements PushClient {
  FirebasePush._();

  /// Connects to the Firebase project in [env]; [NoPush] when it isn't configured or
  /// Firebase can't start (the app works without push).
  static Future<PushClient> init(AppEnv env) async {
    if (!env.hasFirebase) return const NoPush();
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: env.firebaseApiKey,
          appId: env.firebaseAppId,
          messagingSenderId: env.firebaseSenderId,
          projectId: env.firebaseProjectId,
        ),
      );
      return FirebasePush._();
    } on Object {
      return const NoPush();
    }
  }

  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  static PushData _data(RemoteMessage m) => {
    for (final MapEntry(:key, :value) in m.data.entries) key: '$value',
    '_title': ?m.notification?.title,
    '_body': ?m.notification?.body,
  };

  @override
  Future<String?> token() async {
    try {
      return await _fm.getToken();
    } on Object {
      return null; // no Google Play services, or offline
    }
  }

  @override
  Stream<String> get tokenRefresh => _fm.onTokenRefresh;

  @override
  Stream<PushData> get foreground => FirebaseMessaging.onMessage.map(_data);

  @override
  Stream<PushData> get taps => FirebaseMessaging.onMessageOpenedApp.map(_data);

  @override
  Future<PushData?> initialTap() async {
    final m = await _fm.getInitialMessage();
    return m == null ? null : _data(m);
  }

  @override
  Future<bool> requestPermission() async {
    final s = await _fm.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }
}

final pushClientProvider = Provider<PushClient>((ref) => const NoPush());
