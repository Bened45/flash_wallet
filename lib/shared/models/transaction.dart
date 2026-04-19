class Transaction {
  final String id;
  final String type; // BUY_BITCOIN, SELL_BITCOIN, SEND, RECEIVE
  final String status; // PENDING, COMPLETED, FAILED
  final int amountXof;
  final int amountSats;
  final double exchangeRate;
  final String? senderAddress;
  final String? receiverAddress;
  final String? lightningInvoice;
  final String? note;
  final String? mobileMoneyNumber;
  final String? mobileMoneyOperator;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? error;

  Transaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amountXof,
    required this.amountSats,
    required this.exchangeRate,
    this.senderAddress,
    this.receiverAddress,
    this.lightningInvoice,
    this.note,
    this.mobileMoneyNumber,
    this.mobileMoneyOperator,
    required this.createdAt,
    this.completedAt,
    this.error,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final amountXofStr = (json['amount_xof'] as String?)
            ?.replaceAll(' XOF', '')
            .replaceAll(',', '') ?? '0';
    final amountXof = double.tryParse(amountXofStr) ?? 0;
    
    final exchangeRate = (json['exchange_rate'] as num?)?.toDouble() ?? 0;
    // exchange_rate is in satoshis per XOF, invert to get XOF per sat
    final ratePerSat = exchangeRate > 0 ? 1 / (exchangeRate / 100000000) : 3.84;
    final amountSats = ratePerSat > 0 ? (amountXof / ratePerSat).toInt() : 0;

    return Transaction(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? 'PENDING',
      amountXof: amountXof.toInt(),
      amountSats: amountSats,
      exchangeRate: ratePerSat,
      senderAddress: json['sender_address'],
      receiverAddress: json['receiver_address'],
      lightningInvoice: json['lightning_invoice'],
      note: json['note'],
      mobileMoneyNumber: json['number'],
      mobileMoneyOperator: json['operator'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'status': status,
      'amount_xof': '$amountXof XOF',
      'amount_sats': amountSats,
      'exchange_rate': exchangeRate,
      'sender_address': senderAddress,
      'receiver_address': receiverAddress,
      'lightning_invoice': lightningInvoice,
      'note': note,
      'number': mobileMoneyNumber,
      'operator': mobileMoneyOperator,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'error': error,
    };
  }

  Transaction copyWith({
    String? id,
    String? type,
    String? status,
    int? amountXof,
    int? amountSats,
    double? exchangeRate,
    String? senderAddress,
    String? receiverAddress,
    String? lightningInvoice,
    String? note,
    String? mobileMoneyNumber,
    String? mobileMoneyOperator,
    DateTime? createdAt,
    DateTime? completedAt,
    String? error,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      amountXof: amountXof ?? this.amountXof,
      amountSats: amountSats ?? this.amountSats,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      senderAddress: senderAddress ?? this.senderAddress,
      receiverAddress: receiverAddress ?? this.receiverAddress,
      lightningInvoice: lightningInvoice ?? this.lightningInvoice,
      note: note ?? this.note,
      mobileMoneyNumber: mobileMoneyNumber ?? this.mobileMoneyNumber,
      mobileMoneyOperator: mobileMoneyOperator ?? this.mobileMoneyOperator,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
    );
  }

  String get formattedAmountXof {
    return amountXof.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  String get formattedAmountSats {
    return amountSats.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'COMPLETED':
        return '✅ Confirmé';
      case 'PENDING':
        return '⏳ En cours';
      case 'FAILED':
        return '❌ Échoué';
      default:
        return status;
    }
  }
}
