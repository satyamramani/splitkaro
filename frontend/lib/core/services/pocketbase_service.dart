import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

const String _kCustomUrl = String.fromEnvironment('PB_URL', defaultValue: '');

// PocketBase server URL (Local development by default)
String get _pbUrl {
  if (_kCustomUrl.isNotEmpty) {
    return _kCustomUrl;
  }

  if (kIsWeb) {
    return 'http://127.0.0.1:18090';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:18090'; // Android emulator
  }
  return 'http://127.0.0.1:18090'; // iOS / macOS / Desktop
}

final pb = PocketBase(_pbUrl);

final pocketBaseProvider = Provider<PocketBase>((ref) => pb);
