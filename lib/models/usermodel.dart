// lib/models/models.dart
// Flutter models matching all backend Sequelize models

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
        id: json['id'] as int,
        name: json['name'] as String,
        mobile: json['mobile'] as String,
        isVerified: json['isVerified'] as bool? ?? false,
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
// HUB MODEL
// ─────────────────────────────────────────────────────────────────────
class HubModel {
  final int id;
  final String hubName;
  final String hubId;
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

  const HubModel({
    required this.id,
    required this.hubName,
    required this.hubId,
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
  });

  factory HubModel.fromJson(Map<String, dynamic> json) => HubModel(
        id: json['id'] as int,
        hubName: json['hubName'] as String,
        hubId: json['hubId'] as String,
        latitude: json['latitude'] != null
            ? double.tryParse(json['latitude'].toString())
            : null,
        longitude: json['longitude'] != null
            ? double.tryParse(json['longitude'].toString())
            : null,
        hubOwnerName: json['hubOwnerName'] as String?,
        ownerId: json['ownerId'] as String?,
        email: json['email'] as String?,
        mobile: json['mobile'] as String?,
        address: json['address'] as String?,
        bankName: json['bankName'] as String?,
        acNumber: json['acNumber'] as String?,
        ifscCode: json['ifscCode'] as String?,
        deviceCount: json['deviceCount'] as int?,
        operatorName: json['operatorName'] as String?,
        operatorMobile: json['operatorMobile'] as String?,
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
      };
}

// ─────────────────────────────────────────────────────────────────────
// HUB DEVICE MODEL
// ─────────────────────────────────────────────────────────────────────
class HubDeviceModel {
  final int id;
  final int hubId;
  final int deviceId;
  final String deviceCode;
  final String connectivityStatus; // "offline" | "online"
  final int iotStatusCode;
  final bool isActive;
  final DateTime? lastPingAt;

  const HubDeviceModel({
    required this.id,
    required this.hubId,
    required this.deviceId,
    required this.deviceCode,
    required this.connectivityStatus,
    required this.iotStatusCode,
    required this.isActive,
    this.lastPingAt,
  });

  bool get isOnline => connectivityStatus == 'online';

  factory HubDeviceModel.fromJson(Map<String, dynamic> json) => HubDeviceModel(
        id: json['id'] as int,
        hubId: json['hubId'] as int,
        deviceId: json['deviceId'] as int,
        deviceCode: json['deviceCode'] as String,
        connectivityStatus: json['connectivityStatus'] as String? ?? 'offline',
        iotStatusCode: json['iotStatusCode'] as int? ?? 0,
        isActive: json['isActive'] as bool? ?? true,
        lastPingAt: json['lastPingAt'] != null
            ? DateTime.tryParse(json['lastPingAt'].toString())
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'deviceId': deviceId,
        'deviceCode': deviceCode,
        'connectivityStatus': connectivityStatus,
        'iotStatusCode': iotStatusCode,
        'isActive': isActive,
        'lastPingAt': lastPingAt?.toIso8601String(),
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

  factory HubPackageModel.fromJson(Map<String, dynamic> json) =>
      HubPackageModel(
        id: json['id'] as int,
        packageName: json['packageName'] as String,
        description: json['description'] as String?,
        statusCode: json['statusCode'] as int,
        price: double.tryParse(json['price'].toString()) ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'packageName': packageName,
        'description': description,
        'statusCode': statusCode,
        'price': price,
      };
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
  final String status; // "pending" | "paid" | "completed" | "failed"
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
        id: json['id'] as int,
        userId: json['userId'] as int,
        hubId: json['hubId'] as int,
        deviceId: json['deviceId'] as int,
        hubDeviceId: json['hubDeviceId'] as int,
        packageId: json['packageId'] as int,
        amount: double.tryParse(json['amount'].toString()) ?? 0.0,
        status: json['status'] as String? ?? 'pending',
        couponCode: json['couponCode'] as String?,
        couponDiscountPercentage: json['couponDiscountPercentage'] as int?,
        finalAmount: double.tryParse(json['finalAmount'].toString()) ?? 0.0,
        razorpayOrderId: json['razorpayOrderId'] as String? ?? '',
        razorpayPaymentId: json['razorpayPaymentId'] as String? ?? '',
        razorpaySignature: json['razorpaySignature'] as String? ?? '',
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
  });

  Duration get washDuration => washEndTime.difference(washStartTime);

  factory WashHistoryModel.fromJson(Map<String, dynamic> json) =>
      WashHistoryModel(
        id: json['id'] as int,
        userId: json['userId'] as int,
        hubId: json['hubId'] as int,
        deviceId: json['deviceId'] as int,
        orderId: json['orderId'] as int,
        packageId: json['packageId'] as int,
        packageName: json['packageName'] as String,
        amount: double.tryParse(json['amount'].toString()) ?? 0.0,
        razorpayOrderId: json['razorpayOrderId'] as String,
        razorpayPaymentId: json['razorpayPaymentId'] as String,
        washStartTime: DateTime.parse(json['washStartTime'].toString()),
        washEndTime: DateTime.parse(json['washEndTime'].toString()),
        couponCode: json['couponCode'] as String?,
        couponDiscountPercentage: json['couponDiscountPercentage'] as int?,
        finalAmount: double.tryParse(json['finalAmount'].toString()) ?? 0.0,
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
  final int rating; // 1 to 5
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
        id: json['id'] as int,
        userId: json['userId'] as int,
        hubId: json['hubId'] as int,
        deviceId: json['deviceId'] as int,
        orderId: json['orderId'] as int,
        rating: json['rating'] as int,
        comment: json['comment'] as String?,
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