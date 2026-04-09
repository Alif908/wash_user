// lib/models/usermodel.dart
// Flutter models matching all backend Sequelize models
// All fromJson methods use SAFE parsing — no hard casts that can crash.

// ─────────────────────────────────────────────────────────────────────
// SAFE HELPERS  (used by all models below)
// ─────────────────────────────────────────────────────────────────────

/// Safely parse any value to int — handles int, String, double, null
int? _safeInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString());
}

/// Safely parse any value to double — handles double, int, String, null
double _safeDouble(dynamic v, {double fallback = 0.0}) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

/// Safely parse any value to bool — handles bool, int (0/1), String
bool _safeBool(dynamic v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fallback;
}

/// Safely parse any value to String — never throws
String _safeStr(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  return v.toString();
}

// ─────────────────────────────────────────────────────────────────────
// USER MODEL
// ─────────────────────────────────────────────────────────────────────
class UserModel {
  final int id;
  final String name;
  final String mobile;
  final bool isVerified;
  final double? latitude;
  final double? longitude;

  const UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.isVerified,
    this.latitude,
    this.longitude,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: _safeInt(json['id']) ?? 0,
    name: _safeStr(json['name'], fallback: 'User'),
    mobile: _safeStr(json['mobile']),
    isVerified: _safeBool(json['isVerified']),
    latitude: json['latitude'] != null
        ? double.tryParse(json['latitude'].toString())
        : null,
    longitude: json['longitude'] != null
        ? double.tryParse(json['longitude'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mobile': mobile,
    'isVerified': isVerified,
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  String toString() => 'UserModel(id: $id, name: $name, mobile: $mobile)';
}

// ─────────────────────────────────────────────────────────────────────
// HUB MODEL  ✅ Added: distance field
// ─────────────────────────────────────────────────────────────────────
class HubModel {
  final int id;
  final String hubName;
  final String? hubId;
  final double? latitude;
  final double? longitude;
  final String? hubOwnerName;
  final String? ownerId;
  final String? email;
  final String? mobile;
  final String? address;
  final String? bankName;
  final String? acNumber;
  final String? ifscCode;
  final int? deviceCount;
  final String? operatorName;
  final String? operatorMobile;
  final double? distance;

  const HubModel({
    required this.id,
    required this.hubName,
    this.hubId,
    this.latitude,
    this.longitude,
    this.hubOwnerName,
    this.ownerId,
    this.email,
    this.mobile,
    this.address,
    this.bankName,
    this.acNumber,
    this.ifscCode,
    this.deviceCount,
    this.operatorName,
    this.operatorMobile,
    this.distance,
  });

  factory HubModel.fromJson(Map<String, dynamic> json) => HubModel(
    id: _safeInt(json['id']) ?? 0,
    hubName: _safeStr(json['hubName'], fallback: 'Unknown Hub'),
    hubId: json['hubId']?.toString() ?? json['id']?.toString(),
    latitude: json['latitude'] != null
        ? double.tryParse(json['latitude'].toString())
        : null,
    longitude: json['longitude'] != null
        ? double.tryParse(json['longitude'].toString())
        : null,
    hubOwnerName: json['hubOwnerName']?.toString(),
    ownerId: json['ownerId']?.toString(),
    email: json['email']?.toString(),
    mobile: json['mobile']?.toString(),
    address: json['address']?.toString(),
    bankName: json['bankName']?.toString(),
    acNumber: json['acNumber']?.toString(),
    ifscCode: json['ifscCode']?.toString(),
    deviceCount: _safeInt(json['deviceCount']),
    operatorName: json['operatorName']?.toString(),
    operatorMobile: json['operatorMobile']?.toString(),
    distance: json['distance'] != null
        ? double.tryParse(json['distance'].toString())
        : json['distanceKm'] != null
        ? double.tryParse(json['distanceKm'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'hubName': hubName,
    'hubId': hubId,
    'latitude': latitude,
    'longitude': longitude,
    'hubOwnerName': hubOwnerName,
    'ownerId': ownerId,
    'email': email,
    'mobile': mobile,
    'address': address,
    'bankName': bankName,
    'acNumber': acNumber,
    'ifscCode': ifscCode,
    'deviceCount': deviceCount,
    'operatorName': operatorName,
    'operatorMobile': operatorMobile,
    'distance': distance,
  };
}

// ─────────────────────────────────────────────────────────────────────
// HUB DEVICE MODEL
// ─────────────────────────────────────────────────────────────────────
class HubDeviceModel {
  final int id;
  final int? hubId;
  final int? deviceId;
  final String deviceCode;
  final String connectivityStatus;
  final int iotStatusCode;
  final bool isActive;
  final DateTime? lastPingAt;
  final String? deviceName;
  final String? condition;

  const HubDeviceModel({
    required this.id,
    this.hubId,
    this.deviceId,
    required this.deviceCode,
    required this.connectivityStatus,
    required this.iotStatusCode,
    required this.isActive,
    this.lastPingAt,
    this.deviceName,
    this.condition,
  });

  bool get isAvailable => connectivityStatus == 'online' && iotStatusCode == 0;

  bool get isBusy =>
      connectivityStatus == 'online' &&
      (iotStatusCode == 1001 || iotStatusCode == 1002 || iotStatusCode == 1003);

  bool get isCompleted =>
      connectivityStatus == 'online' && iotStatusCode == 2000;

  bool get isOffline => connectivityStatus != 'online';
  String get iotStatusLabel {
    if (iotStatusCode == 0) return 'Available'; // online/offline nokkilla
    if (isBusy) {
      switch (iotStatusCode) {
        case 1001:
          return 'Busy – 10 min wash';
        case 1002:
          return 'Busy – 20 min wash';
        case 1003:
          return 'Busy – 50 min wash';
      }
    }
    if (isCompleted) return 'Cycle Complete';
    if (isOffline) return 'Offline';
    return 'Unavailable';
  }

  factory HubDeviceModel.fromJson(Map<String, dynamic> json) {
    final nested = json['device'] as Map<String, dynamic>?;
    final hubNested = json['hub'] as Map<String, dynamic>?;

    return HubDeviceModel(
      id: _safeInt(json['id']) ?? 0,
      hubId: _safeInt(json['hubId']) ?? _safeInt(hubNested?['id']),
      deviceId: _safeInt(json['deviceId']) ?? _safeInt(nested?['id']),
      deviceCode: _safeStr(json['deviceCode']),
      connectivityStatus: _safeStr(
        json['connectivityStatus'],
        fallback: 'offline',
      ),
      iotStatusCode:
          _safeInt(json['iotStatusCode']) ??
          _safeInt(json['iotStatus']) ??
          _safeInt(json['status']) ??
          0,
      isActive: _safeBool(json['isActive'], fallback: true),
      lastPingAt: json['lastPingAt'] != null
          ? DateTime.tryParse(json['lastPingAt'].toString())
          : null,
      deviceName: nested?['deviceName']?.toString(),
      condition: nested?['condition']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'hubId': hubId,
    'deviceId': deviceId,
    'deviceCode': deviceCode,
    'connectivityStatus': connectivityStatus,
    'iotStatusCode': iotStatusCode,
    'isActive': isActive,
    'lastPingAt': lastPingAt?.toIso8601String(),
    'deviceName': deviceName,
    'condition': condition,
  };
}

// ─────────────────────────────────────────────────────────────────────
// HUB PACKAGE MODEL
// ─────────────────────────────────────────────────────────────────────
class HubPackageModel {
  final int id;
  final String packageName;
  final String? description;
  final int statusCode;
  final double price;

  const HubPackageModel({
    required this.id,
    required this.packageName,
    this.description,
    required this.statusCode,
    required this.price,
  });

  factory HubPackageModel.fromJson(Map<String, dynamic> json) {
    debugPrintPackage(json);

    return HubPackageModel(
      id: _safeInt(json['id']) ?? 0,
      packageName: _safeStr(json['packageName'], fallback: 'Unknown Package'),
      description: json['description']?.toString(),
      statusCode: _safeInt(json['statusCode']) ?? 0,
      price: _safeDouble(json['price']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'packageName': packageName,
    'description': description,
    'statusCode': statusCode,
    'price': price,
  };

  static void debugPrintPackage(Map<String, dynamic> json) {
    // ignore: avoid_print
    print('   [HubPackageModel] Parsing → $json');
    // ignore: avoid_print
    print(
      '   [HubPackageModel]   id          raw=${json['id']}          parsed=${_safeInt(json['id'])}',
    );
    // ignore: avoid_print
    print(
      '   [HubPackageModel]   packageName raw=${json['packageName']} parsed=${_safeStr(json['packageName'])}',
    );
    // ignore: avoid_print
    print(
      '   [HubPackageModel]   statusCode  raw=${json['statusCode']}  parsed=${_safeInt(json['statusCode'])}',
    );
    // ignore: avoid_print
    print(
      '   [HubPackageModel]   price       raw=${json['price']}       parsed=${_safeDouble(json['price'])}',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// ORDER MODEL
// ─────────────────────────────────────────────────────────────────────
class OrderModel {
  final int id;
  final int userId;
  final int hubId;
  final int deviceId;
  final int hubDeviceId;
  final int packageId;
  final double amount;
  final String status;
  final String? couponCode;
  final int? couponDiscountPercentage;
  final double finalAmount;
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final String razorpaySignature;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.hubId,
    required this.deviceId,
    required this.hubDeviceId,
    required this.packageId,
    required this.amount,
    required this.status,
    this.couponCode,
    this.couponDiscountPercentage,
    required this.finalAmount,
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.razorpaySignature,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPaid => status == 'paid';
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
    id: _safeInt(json['id']) ?? 0,
    userId: _safeInt(json['userId']) ?? 0,
    hubId: _safeInt(json['hubId']) ?? 0,
    deviceId: _safeInt(json['deviceId']) ?? 0,
    hubDeviceId: _safeInt(json['hubDeviceId']) ?? 0,
    packageId: _safeInt(json['packageId']) ?? 0,
    amount: _safeDouble(json['amount']),
    status: _safeStr(json['status'], fallback: 'pending'),
    couponCode: json['couponCode']?.toString(),
    couponDiscountPercentage: _safeInt(json['couponDiscountPercentage']),
    finalAmount: _safeDouble(json['finalAmount']),
    razorpayOrderId: _safeStr(json['razorpayOrderId']),
    razorpayPaymentId: _safeStr(json['razorpayPaymentId']),
    razorpaySignature: _safeStr(json['razorpaySignature']),
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null,
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'hubId': hubId,
    'deviceId': deviceId,
    'hubDeviceId': hubDeviceId,
    'packageId': packageId,
    'amount': amount,
    'status': status,
    'couponCode': couponCode,
    'couponDiscountPercentage': couponDiscountPercentage,
    'finalAmount': finalAmount,
    'razorpayOrderId': razorpayOrderId,
    'razorpayPaymentId': razorpayPaymentId,
    'razorpaySignature': razorpaySignature,
  };
}

// ─────────────────────────────────────────────────────────────────────
// WASH HISTORY MODEL
// ─────────────────────────────────────────────────────────────────────
class WashHistoryModel {
  final int id;
  final int userId;
  final int hubId;
  final int deviceId;
  final int orderId;
  final int packageId;
  final String packageName;
  final double amount;
  final String razorpayOrderId;
  final String razorpayPaymentId;
  final DateTime washStartTime;
  final DateTime washEndTime;
  final String? couponCode;
  final int? couponDiscountPercentage;
  final double finalAmount;
  final DateTime? createdAt;

  final String? hubName;
  final String? hubAddress;
  final String? deviceCode;
  final String? deviceName;
  final String? deviceCondition;

  const WashHistoryModel({
    required this.id,
    required this.userId,
    required this.hubId,
    required this.deviceId,
    required this.orderId,
    required this.packageId,
    required this.packageName,
    required this.amount,
    required this.razorpayOrderId,
    required this.razorpayPaymentId,
    required this.washStartTime,
    required this.washEndTime,
    this.couponCode,
    this.couponDiscountPercentage,
    required this.finalAmount,
    this.createdAt,
    this.hubName,
    this.hubAddress,
    this.deviceCode,
    this.deviceName,
    this.deviceCondition,
  });

  Duration get washDuration => washEndTime.difference(washStartTime);
  bool get isCompleted => washEndTime.isBefore(DateTime.now());

  factory WashHistoryModel.fromJson(Map<String, dynamic> json) {
    final hub = json['Hub'] as Map<String, dynamic>?;
    final device = json['Device'] as Map<String, dynamic>?;
    final pkg = json['HubPackage'] as Map<String, dynamic>?;

    // ── FIX: use 'deviceCode' field, not 'deviceId' ──────────────────
    // Also check top-level json in case backend sends it flat
    final String? resolvedDeviceCode =
        device?['deviceCode']?.toString() ??
        device?['id']?.toString() ??
        json['deviceCode']?.toString();

    final String? resolvedDeviceName =
        device?['deviceName']?.toString() ?? json['deviceName']?.toString();

    final String? resolvedDeviceCondition =
        device?['condition']?.toString() ?? json['condition']?.toString();

    return WashHistoryModel(
      id: _safeInt(json['id']) ?? 0,
      userId: _safeInt(json['userId']) ?? 0,
      hubId: _safeInt(json['hubId']) ?? 0,
      deviceId: _safeInt(json['deviceId']) ?? 0,
      orderId: _safeInt(json['orderId']) ?? 0,
      packageId: _safeInt(json['packageId']) ?? 0,
      packageName: _safeStr(pkg?['packageName'] ?? json['packageName']),
      amount: _safeDouble(json['amount']),
      razorpayOrderId: _safeStr(json['razorpayOrderId']),
      razorpayPaymentId: _safeStr(json['razorpayPaymentId']),
      washStartTime:
          DateTime.tryParse(json['washStartTime'].toString()) ?? DateTime.now(),
      washEndTime:
          DateTime.tryParse(json['washEndTime'].toString()) ?? DateTime.now(),
      couponCode: json['couponCode']?.toString(),
      couponDiscountPercentage: _safeInt(json['couponDiscountPercentage']),
      finalAmount: _safeDouble(json['finalAmount']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      hubName: hub?['hubName']?.toString() ?? json['hubName']?.toString(),
      hubAddress: hub?['address']?.toString(),
      deviceCode: resolvedDeviceCode,
      deviceName: resolvedDeviceName,
      deviceCondition: resolvedDeviceCondition,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'hubId': hubId,
    'deviceId': deviceId,
    'orderId': orderId,
    'packageId': packageId,
    'packageName': packageName,
    'amount': amount,
    'razorpayOrderId': razorpayOrderId,
    'razorpayPaymentId': razorpayPaymentId,
    'washStartTime': washStartTime.toIso8601String(),
    'washEndTime': washEndTime.toIso8601String(),
    'couponCode': couponCode,
    'couponDiscountPercentage': couponDiscountPercentage,
    'finalAmount': finalAmount,
    'hubName': hubName,
    'deviceCode': deviceCode,
    'deviceName': deviceName,
  };
}

// ─────────────────────────────────────────────────────────────────────
// FEEDBACK MODEL
// ─────────────────────────────────────────────────────────────────────
class FeedbackModel {
  final int id;
  final int userId;
  final int hubId;
  final int deviceId;
  final int orderId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  const FeedbackModel({
    required this.id,
    required this.userId,
    required this.hubId,
    required this.deviceId,
    required this.orderId,
    required this.rating,
    this.comment,
    this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) => FeedbackModel(
    id: _safeInt(json['id']) ?? 0,
    userId: _safeInt(json['userId']) ?? 0,
    hubId: _safeInt(json['hubId']) ?? 0,
    deviceId: _safeInt(json['deviceId']) ?? 0,
    orderId: _safeInt(json['orderId']) ?? 0,
    rating: _safeInt(json['rating']) ?? 1,
    comment: json['comment']?.toString(),
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString())
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'hubId': hubId,
    'deviceId': deviceId,
    'orderId': orderId,
    'rating': rating,
    'comment': comment,
  };
}
