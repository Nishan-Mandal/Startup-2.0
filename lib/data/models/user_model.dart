import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String userId;
  final String? fcmToken;
  final int? kudos;
  final String name;
  final String? phone;
  final String? role;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  final List<UserPlan>? plans;

  AppUser({
    required this.userId,
    this.fcmToken,
    this.kudos,
    required this.name,
    this.phone,
    this.role,
    this.createdAt,
    this.updatedAt,
    this.plans,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String id) {
    return AppUser(
      userId: id,
      fcmToken: data['fcmToken'],
      kudos: (data['kudos'] as num?)?.toInt() ?? 0,
      name: data['name'] ?? '',
      phone: data['phone'],
      role: data['role'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],

      plans:
          (data['plans'] as List?)?.map((p) => UserPlan.fromMap(p)).toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fcmToken': fcmToken,
      'kudos': kudos,
      'name': name,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'plans': plans?.map((p) => p.toMap()).toList(),
    };
  }
}

class UserPlan {
  final String? planName;
  final String? status;
  final String? paymentType;
  final String? planType;
  final String? subscriptionId;
  final String? paymentId;
  final double? amount;
  final Timestamp? startDate;
  final Timestamp? endDate;
  final Timestamp? createdAt;

  UserPlan({
    this.planName,
    this.status,
    this.paymentType,
    this.planType,
    this.subscriptionId,
    this.paymentId,
    this.amount,
    this.startDate,
    this.endDate,
    this.createdAt,
  });

  factory UserPlan.fromMap(Map<String, dynamic>? data) {
    if (data == null) return UserPlan();

    return UserPlan(
      planName: data['planName'] ?? data['name'], // 🔥 backward compatible
      status: data['status'],
      paymentType: data['payment_type'],
      planType: data['plan_type'],
      subscriptionId: data['subscriptionId'],
      paymentId: data['paymentId'],
      amount: (data['amount'] as num?)?.toDouble(),
      startDate: data['start_date'],
      endDate: data['end_date'],
      createdAt: data['createdAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'planName': planName,
      'status': status,
      'payment_type': paymentType,
      'plan_type': planType,
      'subscriptionId': subscriptionId,
      'paymentId': paymentId,
      'amount': amount,
      'start_date': startDate,
      'end_date': endDate,
      'createdAt': createdAt,
    };
  }
}
