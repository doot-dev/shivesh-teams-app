import 'package:intl/intl.dart';

/// Testing period for a concrete cube sample.
///
/// The wire values are the backend's `CubeTestPeriod` enum — send [apiValue],
/// never `.name`. A standard period means the test date is COMPUTED as
/// castingDate + N days; [custom] means the technician supplies the date of a
/// test that already happened (the backend rejects a future custom date).
enum CubeTestPeriod {
  sevenDays,
  fourteenDays,
  fifteenDays,
  twentyOneDays,
  twentyEightDays,
  custom,
}

/// D21: what the picker offers for NEW tests. 14 and 21 days stay in the enum
/// only so older records still parse and show a label.
const selectableCubeTestPeriods = [
  CubeTestPeriod.sevenDays,
  CubeTestPeriod.fifteenDays,
  CubeTestPeriod.twentyEightDays,
  CubeTestPeriod.custom,
];

extension CubeTestPeriodX on CubeTestPeriod {
  String get apiValue {
    switch (this) {
      case CubeTestPeriod.sevenDays:
        return 'SEVEN_DAYS';
      case CubeTestPeriod.fourteenDays:
        return 'FOURTEEN_DAYS';
      case CubeTestPeriod.fifteenDays:
        return 'FIFTEEN_DAYS';
      case CubeTestPeriod.twentyOneDays:
        return 'TWENTYONE_DAYS';
      case CubeTestPeriod.twentyEightDays:
        return 'TWENTYEIGHT_DAYS';
      case CubeTestPeriod.custom:
        return 'CUSTOM';
    }
  }

  String get label {
    switch (this) {
      case CubeTestPeriod.sevenDays:
        return '7 days';
      case CubeTestPeriod.fourteenDays:
        return '14 days';
      case CubeTestPeriod.fifteenDays:
        return '15 days';
      case CubeTestPeriod.twentyOneDays:
        return '21 days';
      case CubeTestPeriod.twentyEightDays:
        return '28 days';
      case CubeTestPeriod.custom:
        return 'Custom date';
    }
  }

  /// Days added to the casting date. Null for [custom], which has no offset.
  int? get days {
    switch (this) {
      case CubeTestPeriod.sevenDays:
        return 7;
      case CubeTestPeriod.fourteenDays:
        return 14;
      case CubeTestPeriod.fifteenDays:
        return 15;
      case CubeTestPeriod.twentyOneDays:
        return 21;
      case CubeTestPeriod.twentyEightDays:
        return 28;
      case CubeTestPeriod.custom:
        return null;
    }
  }

  static CubeTestPeriod fromApi(String? v) {
    switch (v) {
      case 'FOURTEEN_DAYS':
        return CubeTestPeriod.fourteenDays;
      case 'FIFTEEN_DAYS':
        return CubeTestPeriod.fifteenDays;
      case 'TWENTYONE_DAYS':
        return CubeTestPeriod.twentyOneDays;
      case 'TWENTYEIGHT_DAYS':
        return CubeTestPeriod.twentyEightDays;
      case 'CUSTOM':
        return CubeTestPeriod.custom;
      case 'SEVEN_DAYS':
      default:
        return CubeTestPeriod.sevenDays;
    }
  }
}

final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, h:mm a');

/// One cube testing report logged against an order.
///
/// [createdAt] is when the report was actually SUBMITTED, which is not the same
/// as [castingDate]. Cube results legitimately arrive weeks later — often after
/// the order is closed — so the submission time is the audit trail that shows
/// when a late entry was really made.
class CubeTest {
  const CubeTest({
    required this.id,
    required this.castingDate,
    required this.quantity,
    required this.period,
    required this.toDate,
    this.fileUrl,
    this.createdAt,
  });

  final String id;
  final DateTime castingDate;
  final String quantity;
  final CubeTestPeriod period;

  /// The date the cube is/was tested.
  final DateTime toDate;

  /// Server-relative path of the attached result sheet, e.g.
  /// `/uploads/cube-tests/ORD-2025-0001/report-123.pdf`. Needs the API base URL
  /// prefixed before it can be opened — see `CubeTest.absoluteFileUrl`.
  final String? fileUrl;

  /// When this report was submitted (server time). Null on older rows.
  final DateTime? createdAt;

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;

  String get castingDateLabel => _dateFmt.format(castingDate);
  String get testDateLabel => _dateFmt.format(toDate);

  /// "12 Sep 2026, 1:48 PM" — when the technician logged this report.
  String get addedAtLabel =>
      createdAt == null ? '' : _dateTimeFmt.format(createdAt!);

  /// True once the scheduled testing date has arrived.
  /// Test date passed and no result yet (matches the server's DUE status).
  bool get isDue =>
      (fileUrl == null || fileUrl!.isEmpty) && !toDate.isAfter(DateTime.now());

  /// Whole days until the test is due; negative once it has passed.
  int get daysUntilDue {
    final today = DateTime.now();
    final d = DateTime(toDate.year, toDate.month, toDate.day);
    final n = DateTime(today.year, today.month, today.day);
    return d.difference(n).inDays;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is String) return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
    return DateTime.now();
  }

  /// Unlike [_parseDate] this returns null rather than "now" — a missing
  /// timestamp must read as unknown, not as if it were just submitted.
  static DateTime? _parseNullableDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
    return null;
  }

  factory CubeTest.fromJson(Map<String, dynamic> json) => CubeTest(
    id: json['id'] as String? ?? '',
    castingDate: _parseDate(json['castingDate']),
    quantity: json['quantity']?.toString() ?? '',
    period: CubeTestPeriodX.fromApi(json['period'] as String?),
    toDate: _parseDate(json['toDate']),
    fileUrl: json['fileUrl'] as String?,
    createdAt: _parseNullableDate(json['createdAt']),
  );
}

/// A cube test as it appears in the cross-order "All cube tests" feed.
///
/// Same row as [CubeTest] plus the order/project/client labels the backend
/// flattens onto it — the per-order screen already knows which order it is
/// showing, this screen does not. Comes from `GET .../cube-tests`, NOT from
/// the per-order `.../orders/:id/cube-test` endpoint.
class CubeTestEntry {
  const CubeTestEntry({
    required this.test,
    required this.orderId,
    this.productName,
    this.productGrade,
    this.projectName,
    this.siteName,
    this.clientName,
  });

  final CubeTest test;

  /// Human order code (ORD-2025-0001) — used to open the order screen.
  final String orderId;

  final String? productName;
  final String? productGrade;
  final String? projectName;
  final String? siteName;
  final String? clientName;

  /// "M25 — OPC" style label, skipping whichever half is missing.
  String get productLabel =>
      [?productName, ?productGrade].where((s) => s.isNotEmpty).join(' — ');

  /// Project with its site in brackets, when both are known.
  String get projectLabel {
    final p = projectName ?? '';
    final s = siteName ?? '';
    if (p.isEmpty) return s;
    if (s.isEmpty || s == p) return p;
    return '$p ($s)';
  }

  factory CubeTestEntry.fromJson(Map<String, dynamic> json) => CubeTestEntry(
    test: CubeTest.fromJson(json),
    orderId: json['orderId'] as String? ?? '',
    productName: json['productName'] as String?,
    productGrade: json['productGrade'] as String?,
    projectName: json['projectName'] as String?,
    siteName: json['siteName'] as String?,
    clientName: json['clientName'] as String?,
  );
}
