import 'package:pocketbase/pocketbase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

const String _kCustomUrl = String.fromEnvironment('PB_URL', defaultValue: '');

// PocketBase server URL (HTTPS production domain)
String get _pbUrl {
  if (_kCustomUrl.isNotEmpty) {
    return _kCustomUrl;
  }

  return 'https://pocket.chai-tea.duckdns.org';
}

final pb = PocketBase(_pbUrl);

final pocketBaseProvider = Provider<PocketBase>((ref) => pb);
