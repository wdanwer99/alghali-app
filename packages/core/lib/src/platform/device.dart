import 'dart:math' as math;
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backend/backend_error.dart';

/// Phone calls, WhatsApp chats and directions open other apps (brief §6: directions by
/// Google Maps deep link). Each returns false when nothing on the phone can open it.
abstract final class Launch {
  static Future<bool> call(String phone) =>
      _open(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^\d+]'), '')));

  /// WhatsApp with the number in international form (+249…).
  static Future<bool> whatsApp(String phone) =>
      _open(Uri.https('wa.me', '/${phone.replaceAll(RegExp(r'\D'), '')}'));

  /// Directions to a point in Google Maps (or the browser).
  static Future<bool> directions(double lat, double lng) =>
      _open(Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': '$lat,$lng'}));

  /// A point on the map, e.g. where the technician is now.
  static Future<bool> mapAt(double lat, double lng) =>
      _open(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'}));

  /// A web link (e.g. the APK download page).
  static Future<bool> open(String url) {
    final uri = Uri.tryParse(url);
    return uri == null ? Future.value(false) : _open(uri);
  }

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

/// A photo picked for upload, already shrunk on the phone (D-008: compress client-side).
typedef PickedPhoto = ({Uint8List bytes, String fileName});

abstract final class Photos {
  static final _picker = ImagePicker();

  /// A photo from the camera or the gallery, at most 1600 px and JPEG quality 70
  /// (a receipt stays readable at a few hundred KB). Null when the user backs out.
  static Future<PickedPhoto?> pick({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 70,
    );
    if (file == null) return null;
    final name = file.name.contains('.') ? file.name : '${file.name}.jpg';
    return (bytes: await file.readAsBytes(), fileName: name);
  }
}

/// The phone's position, for an address or the technician's trip. Throws
/// [BackendException] `LOCATION_OFF` or `LOCATION_DENIED` so screens can explain.
abstract final class Gps {
  static Future<({double lat, double lng})> here() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const BackendException('LOCATION_OFF');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw const BackendException('LOCATION_DENIED');
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return (lat: p.latitude, lng: p.longitude);
  }
}

/// Straight-line (great-circle) distance in km (D-026: fee bands use straight lines).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 6371.0088 * 2 * math.asin(math.min(1, math.sqrt(a)));
}
