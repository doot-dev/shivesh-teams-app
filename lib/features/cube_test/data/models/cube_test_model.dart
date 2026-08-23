import 'package:intl/intl.dart';

/// Testing period for a concrete cube sample.
///
/// The wire values are the backend's `CubeTestPeriod` enum — send [apiValue],
/// never `.name`. A standard period means the test date is COMPUTED as
/// castingDate + N days; [custom] means the technician supplies the date of a
/// test that already happened (the backend rejects a future custom date).
enum CubeTestPeriod { sevenDays, fourteenDays, twentyOneDays, custom }

extension CubeTestPeriodX on CubeTestPeriod {
  String get apiValue {
    switch (this) {
      case CubeTestPeriod.sevenDays:
        return 'SEVEN_DAYS';
      case CubeTestPeriod.fourteenDays:
        return 'FOURTEEN_DAYS';
      case CubeTestPeriod.twentyOneDays:
        return 'TWENTYONE_DAYS';
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
      case CubeTestPeriod.twentyOneDays:
        return '21 days';
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
      case CubeTestPeriod.twentyOneDays:
        return 21;
      case CubeTestPeriod.custom:
        return null;
    }
  }

  static CubeTestPeriod fromApi(String? v) {
    switch (v) {
      case 'FOURTEEN_DAYS':
        return CubeTestPeriod.fourteenDays;
      case 'TWENTYONE_DAYS':
        return CubeTestPeriod.twentyOneDays;
      case 'CUSTOM':
        return CubeTestPeriod.custom;
      case 'SEVEN_DAYS':
      default:
        return CubeTestPeriod.sevenDays;
    }
  }
}

final _dateFmt = DateFormat('dd MMM yyyy');

/// One cube testing report logged against an order.
class CubeTest {
  const CubeTest({
    required this.id,
    required this.castingDate,
    required this.quantity,
    required this.period,
    required this.toDate,
    this.fileUrl,
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

  bool get hasFile => fileUrl != null && fileUrl!.isNotEmpty;

  String get castingDateLabel => _dateFmt.format(castingDate);
  String get testDateLabel => _dateFmt.format(toDate);

  /// True once the scheduled testing date has arrived.
  bool get isDue => !toDate.isAfter(DateTime.now());

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

  factory CubeTest.fromJson(Map<String, dynamic> json) => CubeTest(
        id: json['id'] as String? ?? '',
        castingDate: _parseDate(json['castingDate']),
        quantity: json['quantity']?.toString() ?? '',
        period: CubeTestPeriodX.fromApi(json['period'] as String?),
        toDate: _parseDate(json['toDate']),
        fileUrl: json['fileUrl'] as String?,
      );
}
