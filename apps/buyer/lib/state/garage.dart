import 'dart:async';

import 'package:alghali_core/alghali_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'outbox.dart';
import 'session.dart';

@immutable
class GarageState {
  const GarageState({this.vehicles = const [], this.selectedId});

  final List<GarageVehicle> vehicles;
  final String? selectedId;

  GarageVehicle? get selected =>
      vehicles.where((v) => v.id == selectedId).firstOrNull ?? vehicles.firstOrNull;
}

/// My Garage, kept on the phone so it works offline and before sign-in. Signed in, the
/// account's cars (`garage_vehicles`) are the truth: changes go through the outbox, and
/// cars added as a guest are saved to the account at sign-in.
class GarageController extends Notifier<GarageState> {
  static const _key = 'garage';
  static const _selectedKey = 'garage_selected';

  @override
  GarageState build() {
    ref.listen(sessionProvider.select((s) => s.userId), (prev, next) {
      if (next != null && prev != next) unawaited(_syncWithAccount());
      if (next == null && prev != null) unawaited(_clear());
    });
    final prefs = ref.watch(sharedPreferencesProvider);
    final vehicles = [
      for (final row in prefs.getStringList(_key) ?? const <String>[])
        if (row.split('|') case [final id, final variantId])
          GarageVehicle(id: id, variantId: variantId),
    ];
    if (ref.read(sessionProvider).signedIn) Future.microtask(_syncWithAccount);
    return GarageState(vehicles: vehicles, selectedId: prefs.getString(_selectedKey));
  }

  bool get _signedIn => ref.read(sessionProvider).signedIn;

  Future<void> add(String variantId) async {
    final existing = state.vehicles.where((v) => v.variantId == variantId).firstOrNull;
    final vehicle = existing ?? GarageVehicle(id: newId(), variantId: variantId);
    state = GarageState(
      vehicles: existing == null ? [...state.vehicles, vehicle] : state.vehicles,
      selectedId: vehicle.id,
    );
    await _persist();
    if (!_signedIn) return;
    if (existing == null) {
      await queue(ref, BuyerOps.garageAdd, {
        'id': vehicle.id,
        'variant_id': variantId,
        'is_default': true,
      });
    } else {
      await queue(ref, BuyerOps.garageDefault, {'id': vehicle.id});
    }
  }

  Future<void> select(String id) async {
    state = GarageState(vehicles: state.vehicles, selectedId: id);
    await _persist();
    if (_signedIn) await queue(ref, BuyerOps.garageDefault, {'id': id});
  }

  Future<void> remove(String id) async {
    final rest = state.vehicles.where((v) => v.id != id).toList();
    state = GarageState(
      vehicles: rest,
      selectedId: state.selectedId == id ? rest.firstOrNull?.id : state.selectedId,
    );
    await _persist();
    if (_signedIn) await queue(ref, BuyerOps.garageRemove, {'id': id});
  }

  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  /// The account's cars plus the phone's: cars only on the phone (added as a guest, or
  /// still waiting in the outbox) are saved to the account. Replaying an add the server
  /// already has is harmless (the car's id is chosen here).
  Future<void> _syncWithAccount() async {
    final selectedVariant = state.selected?.variantId;
    try {
      final cars = await ref.read(garageRepositoryProvider).list();
      final known = {for (final c in cars) c.variantId};
      final uploaded = <GarageVehicle>[];
      for (final v in state.vehicles.where((v) => !known.contains(v.variantId))) {
        final id = _uuid.hasMatch(v.id) ? v.id : newId();
        uploaded.add(GarageVehicle(id: id, variantId: v.variantId));
        await queue(ref, BuyerOps.garageAdd, {
          'id': id,
          'variant_id': v.variantId,
          'is_default': v.variantId == selectedVariant,
        });
      }
      final all = [...cars, ...uploaded];
      final selected =
          all.where((c) => c.variantId == selectedVariant).firstOrNull ??
          all.where((c) => c.isDefault).firstOrNull ??
          all.firstOrNull;
      state = GarageState(vehicles: all, selectedId: selected?.id);
      await _persist();
    } on BackendException {
      // Offline: keep the phone's list.
    }
  }

  Future<void> _clear() async {
    state = const GarageState();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(_key, [for (final v in state.vehicles) '${v.id}|${v.variantId}']);
    final selected = state.selected?.id;
    if (selected == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, selected);
    }
  }
}

final garageProvider = NotifierProvider<GarageController, GarageState>(GarageController.new);

/// The variant all searches and fit badges use; null when no car is saved.
final selectedVariantProvider = Provider<String?>(
  (ref) => ref.watch(garageProvider.select((g) => g.selected?.variantId)),
);
