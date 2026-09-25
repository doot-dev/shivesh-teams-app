const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Lenient ISO parse — the API sends `createdAt` as a string, but a null or a
/// malformed value must not blow up an entire order payload.
DateTime? _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// "12 Sep 2026, 1:48 PM" in the device's local timezone.
String _fmtDateTime(DateTime dt) {
  final d = dt.toLocal();
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final meridiem = d.hour < 12 ? 'AM' : 'PM';
  return '${d.day} ${_months[d.month - 1]} ${d.year}, $hour12:$minute $meridiem';
}

String _fmtTimeAgo(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  } catch (_) {
    return '';
  }
}

/// The three delivery steps a technician moves an order through:
/// Confirmed → On the way → Reached.
///
/// These map onto the backend's `deliveryStatus` enum
/// (ASSIGNED / IN_TRANSIT / DELIVERED / COMPLETED) via [apiValue] and
/// [mapDeliveryStatus], so never send a raw `.name` to the API — always go
/// through [apiValue].
///
/// A fourth `dispatched` step was removed deliberately: it had no distinct
/// server value (it reported ASSIGNED, exactly like `confirmed`), so picking it
/// looked like progress to the technician while the backend recorded no change
/// at all. The order of these values also drives [DeliveryTracker], which
/// renders one dot per value — adding a step here adds a dot there.
// W32: "Reached" is now its own server step (REACHED); "Delivered" (poured,
// challan in) follows it. The tracker draws one dot per value.
enum DeliveryStatus { confirmed, onTheWay, reached, delivered }

extension DeliveryStatusLabel on DeliveryStatus {
  String get label {
    switch (this) {
      case DeliveryStatus.confirmed:
        return 'Confirmed';
      case DeliveryStatus.onTheWay:
        return 'On the way';
      case DeliveryStatus.reached:
        return 'Reached';
      case DeliveryStatus.delivered:
        return 'Delivered';
    }
  }

  /// The value the backend's `PUT /orders/:id/status` accepts.
  String get apiValue {
    switch (this) {
      case DeliveryStatus.confirmed:
        return 'ASSIGNED';
      case DeliveryStatus.onTheWay:
        return 'IN_TRANSIT';
      case DeliveryStatus.reached:
        return 'REACHED';
      case DeliveryStatus.delivered:
        return 'DELIVERED';
    }
  }

  double get progress {
    switch (this) {
      case DeliveryStatus.confirmed:
        return 0.0;
      case DeliveryStatus.onTheWay:
        return 0.33;
      case DeliveryStatus.reached:
        return 0.67;
      case DeliveryStatus.delivered:
        return 1.0;
    }
  }
}

DeliveryStatus mapDeliveryStatus(String? s) {
  switch (s) {
    case 'IN_TRANSIT':
      return DeliveryStatus.onTheWay;
    case 'REACHED':
      return DeliveryStatus.reached;
    case 'DELIVERED':
    case 'COMPLETED':
      return DeliveryStatus.delivered;
    case 'ASSIGNED':
    default:
      return DeliveryStatus.confirmed;
  }
}

/// One transit mixer logged against an order.
///
/// [createdAt] is the server's record of WHEN this TM was entered, which
/// matters because TMs can be added after an order closes — the entry is
/// backdated paperwork, and [addedAtLabel] is what tells the office it arrived
/// late rather than silently looking like it was there all along.
class TmDetail {
  TmDetail({
    required this.id,
    required this.tmNumber,
    required this.truckNo,
    required this.qty,
    required this.batchStartTime,
    required this.batchEndTime,
    required this.challanNo,
    this.challanUrl,
    this.status = DeliveryStatus.confirmed,
    this.createdAt,
    this.approvalStatus = 'PENDING',
    this.rejectionReason,
  });

  /// Office review: PENDING / ACCEPTED / REJECTED. Once reviewed, the truck is
  /// locked in the app (P1.4).
  final String approvalStatus;
  final String? rejectionReason;

  bool get isReviewed => approvalStatus != 'PENDING';
  bool get isRejected => approvalStatus == 'REJECTED';

  /// "Reached site" can be tapped while the truck is assigned or on the way.
  bool get canMarkReached =>
      !isReviewed && (status == DeliveryStatus.confirmed || status == DeliveryStatus.onTheWay);

  final String id;
  final String tmNumber;
  final String truckNo;
  final String qty;
  final String batchStartTime;
  final String batchEndTime;
  final String challanNo;
  final String? challanUrl;
  DeliveryStatus status;

  /// When the technician actually submitted this TM (server time).
  final DateTime? createdAt;

  bool get hasChallanFile => (challanUrl ?? '').isNotEmpty;

  /// "12 Sep 2026, 1:48 PM" — the moment this entry was recorded.
  String get addedAtLabel => createdAt == null ? '' : _fmtDateTime(createdAt!);

  factory TmDetail.fromJson(Map<String, dynamic> json) => TmDetail(
        id: json['id'] as String? ?? json['tmId'] as String? ?? '',
        tmNumber: json['tmNumber'] as String? ?? '',
        truckNo: json['truckNo'] as String? ?? '',
        qty: json['qty'] as String? ?? '',
        batchStartTime: json['batchStartTime'] as String? ?? '',
        batchEndTime: json['batchEndTime'] as String? ?? '',
        challanNo: json['challanNo'] as String? ?? '',
        challanUrl: json['challanUrl'] as String?,
        status: mapDeliveryStatus(json['status'] as String?),
        createdAt: _parseDate(json['createdAt']),
        approvalStatus: json['approvalStatus'] as String? ?? 'PENDING',
        rejectionReason: json['rejectionReason'] as String?,
      );
}

class VendorDetail {
  const VendorDetail({
    required this.handlerName,
    required this.contactNo,
    required this.plantLocation,
  });

  final String handlerName;
  final String contactNo;
  final String plantLocation;

  static const empty = VendorDetail(
    handlerName: '',
    contactNo: '',
    plantLocation: '',
  );

  bool get isEmpty =>
      handlerName.isEmpty && contactNo.isEmpty && plantLocation.isEmpty;
}

class Comment {
  const Comment({
    required this.author,
    required this.message,
    required this.timeAgo,
    required this.isMe,
  });

  final String author;
  final String message;
  final String timeAgo;
  final bool isMe;

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        author: json['authorName'] as String? ?? '',
        message: json['message'] as String? ?? '',
        timeAgo: _fmtTimeAgo(json['createdAt'] as String?),
        isMe: (json['authorType'] as String?) == 'FIELD_TECH',
      );
}

class FieldOrder {
  const FieldOrder({
    required this.id,
    required this.projectName,
    required this.clientName,
    required this.vendor,
    required this.product,
    required this.grade,
    required this.quantity,
    required this.date,
    required this.time,
    required this.location,
    required this.isActive,
    this.status = '',
    this.deliveryStatus = DeliveryStatus.confirmed,
    this.vendorDetail = VendorDetail.empty,
    this.tmDetails = const [],
    this.comments = const [],
  });

  /// The human order code (e.g. ORD-2025-0001) — this is what every
  /// `/orders/:orderId` route expects, NOT the cuid primary key.
  final String id;
  final String projectName;
  final String clientName;
  final String vendor;
  final String product;
  final String grade;
  final String quantity;
  final String date;
  final String time;
  final String location;
  final bool isActive;

  /// Raw order status (NEW / CONFIRMED / IN_PROGRESS / DELIVERED / ...).
  final String status;
  final DeliveryStatus deliveryStatus;
  final VendorDetail vendorDetail;
  final List<TmDetail> tmDetails;
  final List<Comment> comments;

  bool get hasVendor => vendor.isNotEmpty;

  /// Parse an order from the tech API.
  ///
  /// IMPORTANT — the payload nests vendor info under a `vendors` LIST (an order
  /// can be split across plants; see buildOrderSelect in the backend's mobile
  /// orderController). An earlier version of this model read top-level `vendor`
  /// / `vendorHandler` / `vendorLocation` keys that the API never sends, so the
  /// vendor name and the entire "Vendor Details" card silently rendered blank.
  /// Read the first entry of `vendors` instead.
  factory FieldOrder.fromJson(Map<String, dynamic> json) {
    final project = json['project'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>?;

    final vendors = (json['vendors'] as List<dynamic>?) ?? const [];
    final firstVendor =
        vendors.isNotEmpty ? vendors.first as Map<String, dynamic> : null;
    final vendorMap = firstVendor?['vendor'] as Map<String, dynamic>?;
    final vendorHandler = firstVendor?['vendorHandler'] as Map<String, dynamic>?;
    final vendorLocation =
        firstVendor?['vendorLocation'] as Map<String, dynamic>?;

    final tmList = (json['tmDetails'] as List<dynamic>?) ?? const [];
    final commentList = (json['comments'] as List<dynamic>?) ?? const [];

    return FieldOrder(
      id: json['orderId'] as String? ?? json['id'] as String? ?? '',
      projectName: project?['projectName'] as String? ?? '',
      clientName: client?['companyName'] as String? ?? '',
      vendor: vendorMap?['companyName'] as String? ?? '',
      product: json['productName'] as String? ?? '',
      grade: json['productGrade'] as String? ?? '',
      quantity: json['quantity'] as String? ?? '',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      location: project?['projectLocation'] as String? ??
          project?['siteName'] as String? ??
          json['deliveryAddress'] as String? ??
          vendorLocation?['address'] as String? ??
          '',
      isActive: json['isActive'] as bool? ?? false,
      status: json['status'] as String? ?? '',
      deliveryStatus: mapDeliveryStatus(json['deliveryStatus'] as String?),
      vendorDetail: (vendorHandler != null || vendorLocation != null)
          ? VendorDetail(
              handlerName: vendorHandler?['name'] as String? ?? '',
              contactNo: vendorHandler?['phone'] as String? ?? '',
              plantLocation: vendorLocation?['address'] as String? ??
                  vendorLocation?['plantName'] as String? ??
                  '',
            )
          : VendorDetail.empty,
      tmDetails: tmList
          .map((t) => TmDetail.fromJson(t as Map<String, dynamic>))
          .toList(),
      comments: commentList
          .map((c) => Comment.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
