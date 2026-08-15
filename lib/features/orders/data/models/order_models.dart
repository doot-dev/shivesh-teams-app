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

enum DeliveryStatus { confirmed, dispatched, onTheWay, reached }

extension DeliveryStatusLabel on DeliveryStatus {
  String get label {
    switch (this) {
      case DeliveryStatus.confirmed:
        return 'Confirmed';
      case DeliveryStatus.dispatched:
        return 'Dispatched';
      case DeliveryStatus.onTheWay:
        return 'On the way';
      case DeliveryStatus.reached:
        return 'Reached';
    }
  }

  double get progress {
    switch (this) {
      case DeliveryStatus.confirmed:
        return 0.0;
      case DeliveryStatus.dispatched:
        return 0.33;
      case DeliveryStatus.onTheWay:
        return 0.66;
      case DeliveryStatus.reached:
        return 1.0;
    }
  }
}

DeliveryStatus _mapDeliveryStatus(String? s) {
  switch (s) {
    case 'IN_TRANSIT':
      return DeliveryStatus.onTheWay;
    case 'DELIVERED':
    case 'COMPLETED':
      return DeliveryStatus.reached;
    case 'ASSIGNED':
    default:
      return DeliveryStatus.confirmed;
  }
}

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
  });

  final String id;
  final String tmNumber;
  final String truckNo;
  final String qty;
  final String batchStartTime;
  final String batchEndTime;
  final String challanNo;
  final String? challanUrl;
  DeliveryStatus status;

  factory TmDetail.fromJson(Map<String, dynamic> json) => TmDetail(
        id: json['id'] as String? ?? json['tmId'] as String? ?? '',
        tmNumber: json['tmNumber'] as String? ?? '',
        truckNo: json['truckNo'] as String? ?? '',
        qty: json['qty'] as String? ?? '',
        batchStartTime: json['batchStartTime'] as String? ?? '',
        batchEndTime: json['batchEndTime'] as String? ?? '',
        challanNo: json['challanNo'] as String? ?? '',
        challanUrl: json['challanUrl'] as String?,
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
    this.deliveryStatus = DeliveryStatus.confirmed,
    this.vendorDetail = VendorDetail.empty,
    this.tmDetails = const [],
    this.comments = const [],
  });

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
  final DeliveryStatus deliveryStatus;
  final VendorDetail vendorDetail;
  final List<TmDetail> tmDetails;
  final List<Comment> comments;

  factory FieldOrder.fromJson(Map<String, dynamic> json) {
    final project = json['project'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>?;
    final vendorMap = json['vendor'] as Map<String, dynamic>?;
    final vendorHandler = json['vendorHandler'] as Map<String, dynamic>?;
    final vendorLocation = json['vendorLocation'] as Map<String, dynamic>?;
    final tmList = (json['tmDetails'] as List<dynamic>?) ?? [];
    final commentList = (json['comments'] as List<dynamic>?) ?? [];

    final isActive = json['isActive'] as bool? ?? false;

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
          vendorLocation?['address'] as String? ??
          '',
      isActive: isActive,
      deliveryStatus: _mapDeliveryStatus(json['deliveryStatus'] as String?),
      vendorDetail: vendorHandler != null
          ? VendorDetail(
              handlerName: vendorHandler['name'] as String? ?? '',
              contactNo: vendorHandler['phone'] as String? ?? '',
              plantLocation: vendorLocation?['address'] as String? ?? '',
            )
          : VendorDetail.empty,
      tmDetails:
          tmList.map((t) => TmDetail.fromJson(t as Map<String, dynamic>)).toList(),
      comments:
          commentList.map((c) => Comment.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }
}
