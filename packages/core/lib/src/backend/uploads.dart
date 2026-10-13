import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_error.dart';

/// The signed-in user's id: private uploads go under it. SESSION_EXPIRED when signed out.
String signedInUserId(SupabaseClient client) =>
    client.auth.currentUser?.id ?? (throw const BackendException('SESSION_EXPIRED', status: 401));

/// Content type for an upload, from its file name (the private buckets only take
/// images, PDF receipts and short audio).
String mimeOf(String fileName) => switch (extensionOf(fileName)) {
  '.png' => 'image/png',
  '.webp' => 'image/webp',
  '.pdf' => 'application/pdf',
  '.m4a' => 'audio/mp4',
  '.aac' => 'audio/aac',
  '.mp3' => 'audio/mpeg',
  _ => 'image/jpeg',
};

/// The lower-case extension with its dot; `.jpg` when the name has none.
String extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot < 0 ? '.jpg' : fileName.substring(dot).toLowerCase();
}
