import 'dart:convert';
import 'dart:io';

/// Real responses captured from alghali-dev (see infra/scripts/seed-demo.mjs), so the
/// parsers are checked against what the server actually sends.
Object? fixture(String name) => jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
