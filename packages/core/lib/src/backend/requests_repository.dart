import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import '../models/commerce.dart';
import '../models/partner.dart';
import 'backend_error.dart';
import 'uploads.dart';

/// A photo to attach to a request.
typedef RequestPhoto = ({Uint8List bytes, String fileName});

/// Photo requests: a buyer describes a part they can't find (up to 4 photos); matching
/// shops answer with offers the buyer can add to the cart.
class RequestsRepository {
  RequestsRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'request-photos';

  /// Uploads the photos to the buyer's folder, then opens the request. At most 10 open
  /// requests per buyer (TOO_MANY_REQUESTS).
  Future<PartRequest> create({
    required String note,
    String? variantId,
    String? categoryId,
    List<RequestPhoto> photos = const [],
    String? idem,
  }) => guard(() async {
    final keys = <String>[];
    if (photos.isNotEmpty) {
      final uid = signedInUserId(_client);
      for (final p in photos) {
        final key = '$uid/${newIdempotencyKey()}${extensionOf(p.fileName)}';
        await _client.storage
            .from(_bucket)
            .uploadBinary(key, p.bytes, fileOptions: FileOptions(contentType: mimeOf(p.fileName)));
        keys.add(key);
      }
    }
    final row = await _client.rpc<Json>(
      'create_part_request',
      params: {
        'p_note': note,
        'p_variant_id': variantId,
        'p_category_id': categoryId,
        'p_image_keys': keys,
        'p_idem': idem ?? newIdempotencyKey(),
      },
    );
    return PartRequest.fromJson(row);
  });

  /// The buyer's requests with every offer on them, newest first.
  Future<List<PartRequest>> mine({int limit = 30}) => guard(() async {
    final rows = await _client
        .from('part_requests')
        .select('*, part_offers(*)')
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) PartRequest.fromJson(r)];
  });

  /// Closes the request; its live offers expire.
  Future<void> close(String requestId) =>
      guard(() => _client.rpc<void>('close_part_request', params: {'p_request_id': requestId}));

  /// Hour-long links to request photos (the buyer's own, or an open request for shops),
  /// by key. Photos that can't be signed are left out.
  Future<Map<String, String>> photoUrls(List<String> keys) => guard(() async {
    if (keys.isEmpty) return const {};
    final urls = await _client.storage.from(_bucket).createSignedUrlsResult(keys, 3600);
    return {for (final u in urls.whereType<SignedUrlSuccess>()) u.path: u.signedUrl};
  });

  /// Open requests in the shop's specialities, newest first.
  Future<List<OpenRequest>> openForShop(String shopId, {int limit = 30, int offset = 0}) =>
      guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'shop_open_requests',
          params: {'p_shop_id': shopId, 'p_limit': limit, 'p_offset': offset},
        );
        return [for (final r in rows.cast<Json>()) OpenRequest.fromJson(r)];
      });

  /// Replaces the shop's previous offer on the request, if any.
  Future<PartOffer> makeOffer(String shopId, String requestId, OfferDraft offer, {String? idem}) =>
      guard(() async {
        final row = await _client.rpc<Json>(
          'shop_make_offer',
          params: {
            'p_shop_id': shopId,
            'p_request_id': requestId,
            'p_title_ar': offer.title,
            'p_condition': offer.condition.code,
            'p_price_sdg': offer.priceSdg,
            'p_warranty_days': offer.warrantyDays,
            'p_note_ar': offer.note,
            'p_part_id': offer.partId,
            'p_image_key': offer.imageKey,
            'p_valid_hours': offer.validHours,
            'p_idem': idem ?? newIdempotencyKey(),
          },
        );
        return PartOffer.fromJson(row);
      });

  Future<void> withdrawOffer(String shopId, String offerId) => guard(
    () => _client.rpc<void>(
      'shop_withdraw_offer',
      params: {'p_shop_id': shopId, 'p_offer_id': offerId},
    ),
  );
}
