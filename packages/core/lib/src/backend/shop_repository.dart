import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/catalogue.dart';
import '../models/commerce.dart';
import '../models/partner.dart';
import '../models/tint.dart';
import '../platform/media.dart';
import 'backend_error.dart';
import 'read_cache.dart';

/// A part name suggestion while a shop types a quick listing.
@immutable
class PartSuggestion {
  const PartSuggestion({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.verified,
  });

  factory PartSuggestion.fromJson(Json j) => PartSuggestion(
    id: j['id'] as String,
    categoryId: j['category_id'] as String,
    name: LocalizedText.fromJson(j, 'name'),
    verified: j['is_verified'] as bool,
  );

  final String id;
  final String categoryId;
  final LocalizedText name;
  final bool verified;
}

/// A shop's own data: applying, profile, staff, stock and Excel imports. Calls check on
/// the server that the user works at the shop (FORBIDDEN otherwise). Mutations take an
/// idempotency key so the offline outbox can replay them; one is made if none is given.
class ShopRepository with CachedReads {
  ShopRepository(this._client, {this.cache});

  final SupabaseClient _client;
  @override
  final ReadCache? cache;

  static const _xlsx = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Returns the new shop's id. It stays PENDING until an admin approves it.
  Future<String> apply(ShopApplication application, {String? idem}) => guard(() async {
    final row = await _client.rpc<Json>(
      'apply_as_shop',
      params: {...application.toParams(), 'p_idem': idem ?? newIdempotencyKey()},
    );
    return row['id'] as String;
  });

  /// Only the keys in [patch] change (see `shop_update_profile` in docs/API.md).
  Future<Shop> updateProfile(String shopId, Json patch) => guard(() async {
    final row = await _client.rpc<Json>(
      'shop_update_profile',
      params: {'p_shop_id': shopId, 'p_patch': patch},
    );
    return Shop.fromJson(row);
  });

  /// The shop as its members see it, also while its application is waiting (D-120).
  Future<Shop> detail(String shopId) => cachedRead(
    '@shop:$shopId',
    () => _client.rpc<Json>('shop_detail', params: {'p_shop_id': shopId}),
    (raw) => Shop.fromJson(raw! as Json),
  );

  /// The shop's window-tint offer (D-149).
  Future<ShopTintSettings> tintSettings(String shopId) => cachedRead(
    '@tint:$shopId',
    () => _client.rpc<Json>('shop_tint_settings', params: {'p_shop_id': shopId}),
    (raw) => ShopTintSettings.fromJson(raw! as Json),
  );

  /// Replaces the shop's tint offer. Offering it needs at least one price
  /// (TINT_PRICE_REQUIRED).
  Future<ShopTintSettings> setTint(
    String shopId, {
    required bool active,
    required Set<int> darkness,
    required Set<TintColour> colours,
    required Map<(TintCarSize, TintItem), int> prices,
  }) => guard(() async {
    final row = await _client.rpc<Json>(
      'shop_set_tint',
      params: {
        'p_shop_id': shopId,
        'p_is_active': active,
        'p_darkness': darkness.toList()..sort(),
        'p_colours': [for (final c in colours) c.code],
        'p_prices': ShopTintSettings.pricesJson(prices),
      },
    );
    return ShopTintSettings.fromJson(row);
  });

  /// "Closed today" until [until]; null opens the shop again (D-119).
  Future<Shop> setClosed(String shopId, DateTime? until) => guard(() async {
    final row = await _client.rpc<Json>(
      'shop_set_closed',
      params: {'p_shop_id': shopId, 'p_until': until?.toUtc().toIso8601String()},
    );
    return Shop.fromJson(row);
  });

  /// Sales per day for the last [days] days and the best sellers.
  Future<ShopInsights> insights(String shopId, {int days = 7}) => cachedRead(
    '@shop.insights:$shopId',
    () => _client.rpc<Json>('shop_insights', params: {'p_shop_id': shopId, 'p_days': days}),
    (raw) => ShopInsights.fromJson(raw! as Json),
  );

  Future<List<StaffMember>> staff(String shopId) => cachedRead(
    '@shop.staff:$shopId',
    () => _client.rpc<List<dynamic>>('shop_staff', params: {'p_shop_id': shopId}),
    (raw) => [
      for (final r in (raw! as List).cast<Json>())
        StaffMember(
          id: r['user_id'] as String,
          name: r['display_name'] as String? ?? '',
          email: r['email'] as String? ?? '',
          role: r['role'] == 'OWNER' ? StaffRole.owner : StaffRole.staff,
          lastActive: DateTime.parse(r['added_at'] as String),
        ),
    ],
  );

  /// The colleague signs up in the partner app first; then the owner adds them by email.
  Future<void> addStaff(String shopId, String email) => guard(
    () =>
        _client.rpc<Json>('shop_add_staff', params: {'p_shop_id': shopId, 'p_email': email.trim()}),
  );

  Future<void> removeStaff(String shopId, String userId) => guard(
    () =>
        _client.rpc<void>('shop_remove_staff', params: {'p_shop_id': shopId, 'p_user_id': userId}),
  );

  Future<List<ShopListing>> listings(
    String shopId, {
    String query = '',
    int limit = 50,
    int offset = 0,
  }) => cachedRead(
    '@shop.stock:$shopId:$query:$offset',
    () => _client.rpc<List<dynamic>>(
      'shop_listings',
      params: {'p_shop_id': shopId, 'p_q': query, 'p_limit': limit, 'p_offset': offset},
    ),
    (raw) => [for (final r in (raw! as List).cast<Json>()) ShopListing.fromJson(r)],
  );

  /// Creates or edits a listing. An edit with an old [ListingDraft.version] fails with
  /// VERSION_CONFLICT; reload the listing and ask the user.
  Future<ShopListing> saveListing(String shopId, ListingDraft draft, {String? idem}) =>
      guard(() async {
        final row = await _client.rpc<Json>(
          'shop_upsert_listing',
          params: {...draft.toParams(shopId), 'p_idem': idem ?? newIdempotencyKey()},
        );
        return ShopListing.fromJson(row);
      });

  /// Applies each edit on its own; check every [BulkResult.ok].
  Future<List<BulkResult>> bulkUpdate(String shopId, List<BulkEdit> edits, {String? idem}) =>
      guard(() async {
        final res = await _client.rpc<Json>(
          'shop_bulk_update',
          params: {
            'p_shop_id': shopId,
            'p_items': [for (final e in edits) e.toJson()],
            'p_idem': idem ?? newIdempotencyKey(),
          },
        );
        return [for (final r in (res['results'] as List).cast<Json>()) BulkResult.fromJson(r)];
      });

  Future<void> archiveListing(String shopId, String listingId) => guard(
    () => _client.rpc<void>(
      'shop_archive_listing',
      params: {'p_shop_id': shopId, 'p_listing_id': listingId},
    ),
  );

  /// Uploads one listing photo in every size under a new base key (or [id], so a replay
  /// from the outbox writes the same files) and returns the key for [setListingImages].
  Future<String> uploadListingPhoto(String shopId, MediaVariants photo, {String? id}) =>
      guard(() async {
        final base = 'shops/$shopId/listings/${id ?? newIdempotencyKey()}';
        final bucket = _client.storage.from('media-public');
        for (final (name, bytes, type) in [
          ('thumb.webp', photo.thumb, 'image/webp'),
          ('medium.webp', photo.medium, 'image/webp'),
          ('large.webp', photo.large, 'image/webp'),
          ('orig.jpg', photo.orig, 'image/jpeg'),
        ]) {
          await bucket.uploadBinary(
            '$base/$name',
            bytes,
            fileOptions: FileOptions(contentType: type, upsert: true),
          );
        }
        return base;
      });

  /// [baseKeys] are photos already uploaded under shops/{shopId}/listings/… (at most 6).
  Future<ShopListing> setListingImages(String shopId, String listingId, List<String> baseKeys) =>
      guard(() async {
        final row = await _client.rpc<Json>(
          'shop_set_listing_images',
          params: {'p_shop_id': shopId, 'p_listing_id': listingId, 'p_base_keys': baseKeys},
        );
        return ShopListing.fromJson(row);
      });

  Future<List<PartSuggestion>> suggestParts(String shopId, String query, {String? categoryId}) =>
      guard(() async {
        final rows = await _client.rpc<List<dynamic>>(
          'suggest_parts',
          params: {'p_q': query, 'p_shop_id': shopId, 'p_category_id': categoryId},
        );
        return [for (final r in rows.cast<Json>()) PartSuggestion.fromJson(r)];
      });

  /// The shop's orders, newest first; [statuses] filters (e.g. the "to do" tab). Orders
  /// still waiting for the buyer's Bankak transfer are not shown.
  Future<List<ShopSubOrder>> orders(
    String shopId, {
    Set<SubOrderStatus>? statuses,
    int limit = 50,
    int offset = 0,
  }) => cachedRead(
    '@shop.orders:$shopId:${statuses?.map((s) => s.code).join(',') ?? ''}:$offset',
    () => _client.rpc<List<dynamic>>(
      'shop_orders',
      params: {
        'p_shop_id': shopId,
        'p_statuses': statuses == null ? null : [for (final s in statuses) s.code],
        'p_limit': limit,
        'p_offset': offset,
      },
    ),
    (raw) => [for (final r in (raw! as List).cast<Json>()) ShopSubOrder.fromJson(r)],
  );

  Future<ShopSubOrder> _act(String fn, String subOrderId, [Json extra = const {}]) =>
      guard(() async {
        final row = await _client.rpc<Json>(fn, params: {'p_sub_order_id': subOrderId, ...extra});
        return ShopSubOrder.fromJson(row);
      });

  /// "Accept": the shop has seen the order (a cash order can no longer be cancelled by
  /// the buyer).
  Future<ShopSubOrder> acknowledge(String subOrderId) => _act('shop_ack_suborder', subOrderId);

  /// The shop can't supply it; a paid order is refunded to the buyer.
  Future<ShopSubOrder> reject(String subOrderId, String reason) =>
      _act('shop_reject_suborder', subOrderId, {'p_reason': reason});

  Future<ShopSubOrder> markReady(String subOrderId) => _act('shop_mark_ready', subOrderId);

  /// Pickup: the buyer collected it. Delivery: it left with the driver. Cash is
  /// recorded as collected by the shop at this point (pickup) or on delivery.
  Future<ShopSubOrder> handOver(String subOrderId) => _act('shop_hand_over', subOrderId);

  Future<ShopSubOrder> markDelivered(String subOrderId) => _act('shop_mark_delivered', subOrderId);

  /// Ledger lines and payouts between [from] and [to] (the last 30 days by default).
  Future<ShopStatement> statement(String shopId, {DateTime? from, DateTime? to}) => cachedRead(
    '@shop.statement:$shopId:${from?.toIso8601String() ?? ''}:${to?.toIso8601String() ?? ''}',
    () => _client.rpc<Json>(
      'shop_statement',
      params: {
        'p_shop_id': shopId,
        'p_from': from?.toUtc().toIso8601String(),
        'p_to': to?.toUtc().toIso8601String(),
      },
    ),
    (raw) => ShopStatement.fromJson(raw! as Json),
  );

  /// Uploads a stock sheet (.xlsx or .csv) and imports it. With [dryRun] nothing is
  /// saved: the report shows what would happen.
  Future<ImportReport> importStock(
    String shopId,
    Uint8List bytes,
    String fileName, {
    bool dryRun = false,
    String? idem,
  }) => guard(() async {
    final csv = fileName.toLowerCase().endsWith('.csv');
    final key = '$shopId/${newIdempotencyKey()}${csv ? '.csv' : '.xlsx'}';
    await _client.storage
        .from('imports')
        .uploadBinary(key, bytes, fileOptions: FileOptions(contentType: csv ? 'text/csv' : _xlsx));
    final res = await _client.functions.invoke(
      'inventory-import',
      body: {'shop_id': shopId, 'file_key': key, 'dry_run': dryRun, 'file_name': fileName},
      headers: {'Idempotency-Key': idem ?? newIdempotencyKey()},
    );
    return ImportReport.fromJson(res.data as Json);
  });
}
