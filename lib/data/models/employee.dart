import '../../core/utils/date_utils.dart';
import 'attendance_status.dart';

/// How an employee's [Employee.salaryAmount] should be read.
enum SalaryType {
  perDay('per_day', 'Per day'),
  monthly('monthly', 'Monthly');

  const SalaryType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static SalaryType fromDb(String? value) =>
      value == SalaryType.monthly.dbValue ? SalaryType.monthly : SalaryType.perDay;
}

/// A person on the owner's roster.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.isActive,
    required this.joinedOn,
    this.ownerId,
    this.mobile,
    this.address,
    this.salaryType = SalaryType.perDay,
    this.salaryAmount,
    this.createdAt,
  });

  /// How many days a monthly wage is spread across to get a daily rate.
  ///
  /// A business-wide setting (Settings › Payroll), defaulting to 30. It is a
  /// mutable static rather than a constant so the owner can set 26 working days,
  /// etc.; it is seeded from preferences at startup. Owners can always override
  /// a single day's pay by hand regardless.
  static int daysInSalaryMonth = 30;

  static const int defaultDaysInSalaryMonth = 30;

  final String id;
  final String? ownerId;
  final String name;

  /// 10 digit Indian mobile without the country code, or null.
  final String? mobile;
  final String? address;
  final bool isActive;
  final DateTime joinedOn;

  /// Whether [salaryAmount] is a daily rate or a monthly wage.
  final SalaryType salaryType;

  /// The configured wage in rupees, or null when no wage is on file.
  final double? salaryAmount;
  final DateTime? createdAt;

  bool get hasMobile => (mobile ?? '').trim().length == 10;

  /// True when a usable wage has been entered.
  bool get hasSalary => (salaryAmount ?? 0) > 0;

  /// The daily rate in rupees, derived from a monthly wage when needed.
  double get perDaySalary {
    final amount = salaryAmount ?? 0;
    return switch (salaryType) {
      SalaryType.monthly => amount / daysInSalaryMonth,
      SalaryType.perDay => amount,
    };
  }

  /// The monthly wage in rupees (derived from the daily rate when needed).
  double get monthlySalary {
    final amount = salaryAmount ?? 0;
    return switch (salaryType) {
      SalaryType.monthly => amount,
      SalaryType.perDay => amount * daysInSalaryMonth,
    };
  }

  /// What one day of the given [status] is worth at this employee's rate,
  /// before any manual override: present = full, half day = half, otherwise 0.
  double defaultAmountFor(AttendanceStatus status) =>
      perDaySalary * status.dayValue;

  /// `+91 98765 43210`
  String get displayMobile {
    if (!hasMobile) return '';
    final m = mobile!.trim();
    return '+91 ${m.substring(0, 5)} ${m.substring(5)}';
  }

  /// Employees are not expected to be marked before they joined.
  bool wasEmployedOn(DateTime day) =>
      !AppDate.dateOnly(day).isBefore(AppDate.dateOnly(joinedOn));

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String?,
      name: (map['name'] as String? ?? '').trim(),
      mobile: (map['mobile'] as String?)?.trim(),
      address: (map['address'] as String?)?.trim(),
      isActive: map['is_active'] as bool? ?? true,
      joinedOn: AppDate.parseYmd(map['joined_on'] as String? ?? ''),
      salaryType: SalaryType.fromDb(map['salary_type'] as String?),
      salaryAmount: _toDouble(map['salary_amount']),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String)?.toLocal(),
    );
  }

  /// Postgres `numeric` can arrive as a num or a string; be tolerant of both.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  /// Payload for insert/update. `id`, `owner_id` and `created_at` are handled
  /// by the repository, so they are deliberately absent here.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name.trim(),
    'mobile': hasMobile ? mobile!.trim() : null,
    'address': (address ?? '').trim().isEmpty ? null : address!.trim(),
    'is_active': isActive,
    'joined_on': AppDate.ymd(joinedOn),
    'salary_type': salaryType.dbValue,
    'salary_amount': salaryAmount,
  };

  Employee copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? mobile,
    bool clearMobile = false,
    String? address,
    bool clearAddress = false,
    bool? isActive,
    DateTime? joinedOn,
    SalaryType? salaryType,
    double? salaryAmount,
    bool clearSalary = false,
    DateTime? createdAt,
  }) {
    return Employee(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      mobile: clearMobile ? null : (mobile ?? this.mobile),
      address: clearAddress ? null : (address ?? this.address),
      isActive: isActive ?? this.isActive,
      joinedOn: joinedOn ?? this.joinedOn,
      salaryType: salaryType ?? this.salaryType,
      salaryAmount: clearSalary ? null : (salaryAmount ?? this.salaryAmount),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Employee && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
