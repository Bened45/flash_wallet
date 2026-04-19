/// Models for Lightning Network operations
import 'dart:convert';

/// Lightning Invoice for receiving payments
class Invoice {
  final String paymentRequest; // The full invoice string (bolt11)
  final String paymentHash;
  final int amountSats;
  final String? memo;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isPaid;
  final DateTime? paidAt;
  final String? descriptionHash;

  Invoice({
    required this.paymentRequest,
    required this.paymentHash,
    required this.amountSats,
    this.memo,
    required this.createdAt,
    this.expiresAt,
    this.isPaid = false,
    this.paidAt,
    this.descriptionHash,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      paymentRequest: json['payment_request'] ?? json['invoice'],
      paymentHash: json['payment_hash'] ?? '',
      amountSats: json['amount_sats'] ?? json['value'] ?? 0,
      memo: json['memo'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      isPaid: json['is_paid'] ?? json['settled'] ?? false,
      paidAt: json['paid_at'] != null 
          ? DateTime.parse(json['paid_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payment_request': paymentRequest,
      'payment_hash': paymentHash,
      'amount_sats': amountSats,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_paid': isPaid,
      'paid_at': paidAt?.toIso8601String(),
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  String get displayAmount {
    if (amountSats >= 1000000) {
      return '${(amountSats / 1000000).toStringAsFixed(2)}M sats';
    } else if (amountSats >= 1000) {
      return '${(amountSats / 1000).toStringAsFixed(1)}k sats';
    }
    return '$amountSats sats';
  }
}

/// Payment result after sending Lightning payment
class PaymentResult {
  final bool success;
  final String? paymentHash;
  final String? preimage; // Payment preimage (proof of payment)
  final int? feeSats; // Routing fee paid
  final String? error;
  final DateTime timestamp;

  PaymentResult({
    required this.success,
    this.paymentHash,
    this.preimage,
    this.feeSats,
    this.error,
    required this.timestamp,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      success: json['success'] ?? json['status'] == 'SUCCEEDED',
      paymentHash: json['payment_hash'],
      preimage: json['payment_preimage'],
      feeSats: json['fee_sats'] ?? json['fee_msat'] != null 
          ? (json['fee_msat'] as num).toInt() ~/ 1000 
          : null,
      error: json['error'] ?? json['failure_reason'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }
}

/// LNURL-pay response from resolving a Lightning Address
class LNURLPayResponse {
  final String callback; // URL to call to get invoice
  final int minSendable; // Minimum amount in millisatoshis
  final int maxSendable; // Maximum amount in millisatoshis
  final String metadata; // JSON metadata (usually just [[text/plain, description]])
  final String? commentAllowed; // Max comment length allowed
  final String? tag; // Should be 'payRequest'

  LNURLPayResponse({
    required this.callback,
    required this.minSendable,
    required this.maxSendable,
    required this.metadata,
    this.commentAllowed,
    this.tag,
  });

  factory LNURLPayResponse.fromJson(Map<String, dynamic> json) {
    return LNURLPayResponse(
      callback: json['callback'] ?? '',
      minSendable: json['minSendable'] ?? json['min'] ?? 1000,
      maxSendable: json['maxSendable'] ?? json['max'] ?? 1000000000,
      metadata: json['metadata'] ?? '',
      commentAllowed: json['commentAllowed']?.toString(),
      tag: json['tag'],
    );
  }

  /// Get minimum sendable in satoshis
  int get minSendableSats => minSendable ~/ 1000;

  /// Get maximum sendable in satoshis
  int get maxSendableSats => maxSendable ~/ 1000;

  /// Parse metadata JSON
  Map<String, dynamic>? get parsedMetadata {
    try {
      final parsed = jsonDecode(metadata.isNotEmpty ? metadata : '[]');
      final list = parsed is List ? parsed : null;
      if (list == null || list.isEmpty) return null;
      final first = list[0] is List ? list[0] : null;
      if (first == null) return null;
      return {
        'type': first[0],
        'description': first[1],
      };
    } catch (e) {
      return null;
    }
  }
}

/// Payment received notification (via WebSocket)
class PaymentReceived {
  final int amountSats;
  final String paymentHash;
  final String? memo;
  final String? sender;
  final DateTime receivedAt;

  PaymentReceived({
    required this.amountSats,
    required this.paymentHash,
    this.memo,
    this.sender,
    required this.receivedAt,
  });

  factory PaymentReceived.fromJson(Map<String, dynamic> json) {
    return PaymentReceived(
      amountSats: json['amount_sats'] ?? json['value'] ?? 0,
      paymentHash: json['payment_hash'] ?? '',
      memo: json['memo'],
      sender: json['sender'],
      receivedAt: json['received_at'] != null 
          ? DateTime.parse(json['received_at']) 
          : DateTime.now(),
    );
  }
}

/// Lightning node info
class NodeInfo {
  final String publicKey;
  final List<String> uris; // URIs the node is reachable at
  final int numActiveChannels;
  final int numPendingChannels;
  final int numInactiveChannels;
  final String? alias;
  final String? color;

  NodeInfo({
    required this.publicKey,
    this.uris = const [],
    this.numActiveChannels = 0,
    this.numPendingChannels = 0,
    this.numInactiveChannels = 0,
    this.alias,
    this.color,
  });

  factory NodeInfo.fromJson(Map<String, dynamic> json) {
    return NodeInfo(
      publicKey: json['identity_pubkey'] ?? json['pubkey'] ?? '',
      uris: List<String>.from(json['uris'] ?? []),
      numActiveChannels: json['num_active_channels'] ?? 0,
      numPendingChannels: json['num_pending_channels'] ?? 0,
      numInactiveChannels: json['num_inactive_channels'] ?? 0,
      alias: json['alias'],
      color: json['color'],
    );
  }
}

/// Channel info for displaying routing capacity
class Channel {
  final String remotePubkey;
  final int localBalance;
  final int remoteBalance;
  final int capacity;
  final bool isActive;
  final String? remoteAlias;

  Channel({
    required this.remotePubkey,
    required this.localBalance,
    required this.remoteBalance,
    required this.capacity,
    required this.isActive,
    this.remoteAlias,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      remotePubkey: json['remote_pubkey'] ?? '',
      localBalance: json['local_balance'] ?? 0,
      remoteBalance: json['remote_balance'] ?? 0,
      capacity: json['capacity'] ?? 0,
      isActive: json['active'] ?? false,
      remoteAlias: json['remote_alias'],
    );
  }

  /// Can we send this amount?
  bool canSend(int amountSats) => localBalance >= amountSats;

  /// Can we receive this amount?
  bool canReceive(int amountSats) => remoteBalance >= amountSats;
}
