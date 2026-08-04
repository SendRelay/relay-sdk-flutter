import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

const String relayDeviceIdStorageKey = 'relay_flutter_device_id';

Future<String> getOrCreateRelayDeviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(relayDeviceIdStorageKey)?.trim();
  if (existing != null && existing.isNotEmpty) {
    return existing;
  }

  final generated = _generateRelayDeviceId();
  await prefs.setString(relayDeviceIdStorageKey, generated);
  return generated;
}

String _generateRelayDeviceId() {
  final nowPart =
      DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(36);
  final rng = Random.secure();
  final randomA = rng.nextInt(0x7fffffff).toRadixString(36).padLeft(7, '0');
  final randomB = rng.nextInt(0x7fffffff).toRadixString(36).padLeft(7, '0');
  return 'relay_flutter_$nowPart$randomA$randomB';
}
