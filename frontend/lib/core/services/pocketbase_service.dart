import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// Check if running on Android emulator, handling Web platform gracefully
String get _pbUrl {
  if (kIsWeb) {
    return 'http://127.0.0.1:8090'; // Web uses localhost
  }
  
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8090'; // Android emulator localhost
  }
  return 'http://127.0.0.1:8090'; // iOS simulator and desktop
}

final pb = PocketBase(_pbUrl);

final pocketBaseProvider = Provider<PocketBase>((ref) => pb);
