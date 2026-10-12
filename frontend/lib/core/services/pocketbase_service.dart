import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kCustomUrl = String.fromEnvironment('PB_URL', defaultValue: '');

// PocketBase server URL
String get pbUrl {
  if (_kCustomUrl.isNotEmpty) {
    return _kCustomUrl;
  }

  return 'https://pocket.chai-tea.duckdns.org';
}

// Global PocketBase instance
late PocketBase pb;

/// Initializes PocketBase with persistent AsyncAuthStore backed by SharedPreferences.
Future<PocketBase> initPocketBase() async {
  final prefs = await SharedPreferences.getInstance();
  final authStore = AsyncAuthStore(
    save: (String data) async => prefs.setString('pb_auth', data),
    clear: () async => prefs.remove('pb_auth'),
    initial: prefs.getString('pb_auth'),
  );

  pb = PocketBase(pbUrl, authStore: authStore);

  // Validate and refresh the stored token in background if one exists
  if (pb.authStore.isValid) {
    () async {
      try {
        await pb.collection('users').authRefresh();
      } catch (e) {
        debugPrint('Background auth refresh: $e');
      }
    }();
  }

  return pb;
}

final pocketBaseProvider = Provider<PocketBase>((ref) => pb);

