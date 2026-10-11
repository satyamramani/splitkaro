import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

const String _kCustomUrl = String.fromEnvironment('PB_URL', defaultValue: '');

// PocketBase server URL (LAN / Self-hosted server)
String get _pbUrl {
  if (_kCustomUrl.isNotEmpty) {
    return _kCustomUrl;
  }

  return 'http://192.168.0.11:18090';
}

final pb = PocketBase(_pbUrl);

final pocketBaseProvider = Provider<PocketBase>((ref) => pb);
