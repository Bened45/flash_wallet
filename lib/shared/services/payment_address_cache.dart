import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Maps payment_hash → Lightning address for sent LND payments.
/// LND does not store the original Lightning address, so we persist it locally
/// at send time and look it up when building the history.
class PaymentAddressCache {
  static const _key = 'payment_address_cache';
  static const _maxEntries = 200;

  /// Saves [address] for a given [paymentHash].
  static Future<void> save(String paymentHash, String address) async {
    if (paymentHash.isEmpty || address.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final map = raw != null
        ? Map<String, String>.from(jsonDecode(raw) as Map)
        : <String, String>{};

    map[paymentHash] = address;

    // Trim oldest entries if we exceed the limit (keep newest by iterating)
    if (map.length > _maxEntries) {
      final trimmed = Map.fromEntries(
        map.entries.toList().reversed.take(_maxEntries).toList().reversed,
      );
      await prefs.setString(_key, jsonEncode(trimmed));
    } else {
      await prefs.setString(_key, jsonEncode(map));
    }
  }

  /// Returns the Lightning address for [paymentHash], or null if not cached.
  static Future<String?> get(String paymentHash) async {
    if (paymentHash.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final map = Map<String, String>.from(jsonDecode(raw) as Map);
    return map[paymentHash];
  }

  /// Loads the entire cache as a map (used for bulk lookup in history).
  static Future<Map<String, String>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }
}
