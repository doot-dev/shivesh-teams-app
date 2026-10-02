class TechnicianProfile {
  const TechnicianProfile({
    required this.name,
    required this.employeeId,
    this.phone,
    this.avatarUrl,
    this.canPlaceOrders = false,
  });

  final String name;
  final String employeeId;
  final String? phone;
  final String? avatarUrl;

  /// The office granted "Order · Place from field app" (2026-10-02).
  final bool canPlaceOrders;

  String get email => phone != null ? '+91 $phone' : '';

  factory TechnicianProfile.fromJson(Map<String, dynamic> json) =>
      TechnicianProfile(
        name: json['name'] as String? ?? '',
        employeeId: json['employeeId'] as String? ?? '',
        phone: json['phone'] as String?,
        canPlaceOrders: json['canPlaceOrders'] as bool? ?? false,
      );
}
