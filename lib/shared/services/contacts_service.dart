import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Contact {
  final String name;
  final String lightningAddress;
  final int color;
  final DateTime lastUsed;
  final int transactionCount;

  Contact({
    required this.name,
    required this.lightningAddress,
    required this.color,
    required this.lastUsed,
    this.transactionCount = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lightningAddress': lightningAddress,
      'color': color,
      'lastUsed': lastUsed.toIso8601String(),
      'transactionCount': transactionCount,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      name: json['name'] as String,
      lightningAddress: json['lightningAddress'] as String,
      color: json['color'] as int,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
      transactionCount: json['transactionCount'] as int? ?? 1,
    );
  }

  String get initials {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Contact copyWith({
    String? name,
    String? lightningAddress,
    int? color,
    DateTime? lastUsed,
    int? transactionCount,
  }) {
    return Contact(
      name: name ?? this.name,
      lightningAddress: lightningAddress ?? this.lightningAddress,
      color: color ?? this.color,
      lastUsed: lastUsed ?? this.lastUsed,
      transactionCount: transactionCount ?? this.transactionCount,
    );
  }
}

class ContactsService {
  static const String _recentKey = 'recent_contacts';
  static const String _favoriteKey = 'favorite_contacts';

  /// Save a contact to recents
  static Future<void> saveRecentContact({
    required String name,
    required String lightningAddress,
    int? color,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = await getRecentContacts();
    
    // Remove if already exists
    recents.removeWhere((c) => c.lightningAddress == lightningAddress);
    
    // Add to front with updated timestamp
    final colors = [0xFF9B59B6, 0xFF1ABC9C, 0xFFE67E22, 0xFF3498DB, 0xFFE74C3C, 0xFF2ECC71];
    final newContact = Contact(
      name: name.isNotEmpty ? name : lightningAddress.split('@').first,
      lightningAddress: lightningAddress,
      color: color ?? colors[recents.length % colors.length],
      lastUsed: DateTime.now(),
      transactionCount: 1,
    );
    
    recents.insert(0, newContact);
    
    // Keep only last 10
    final limited = recents.take(10).toList();
    
    final jsonList = limited.map((c) => c.toJson()).toList();
    await prefs.setString(_recentKey, jsonEncode(jsonList));
  }

  /// Get recent contacts
  static Future<List<Contact>> getRecentContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_recentKey);
    
    if (jsonString == null) return [];
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((j) => Contact.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Remove a contact from recents
  static Future<void> removeRecentContact(String lightningAddress) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = await getRecentContacts();
    recents.removeWhere((c) => c.lightningAddress == lightningAddress);
    
    final jsonList = recents.map((c) => c.toJson()).toList();
    await prefs.setString(_recentKey, jsonEncode(jsonList));
  }

  /// Clear all recent contacts
  static Future<void> clearRecentContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }

  /// Validate Lightning address format
  static bool isValidLightningAddress(String address) {
    // Basic format: name@domain
    final regex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(address.trim());
  }

  /// Parse Lightning address
  static Map<String, String> parseLightningAddress(String address) {
    final parts = address.trim().split('@');
    if (parts.length != 2) {
      return {'name': '', 'domain': ''};
    }
    return {
      'name': parts[0],
      'domain': parts[1],
    };
  }
}
