import '../../core/utils/date_utils.dart';

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
    this.createdAt,
  });

  final String id;
  final String? ownerId;
  final String name;

  /// 10 digit Indian mobile without the country code, or null.
  final String? mobile;
  final String? address;
  final bool isActive;
  final DateTime joinedOn;
  final DateTime? createdAt;

  bool get hasMobile => (mobile ?? '').trim().length == 10;

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
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String)?.toLocal(),
    );
  }

  /// Payload for insert/update. `id`, `owner_id` and `created_at` are handled
  /// by the repository, so they are deliberately absent here.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name.trim(),
    'mobile': hasMobile ? mobile!.trim() : null,
    'address': (address ?? '').trim().isEmpty ? null : address!.trim(),
    'is_active': isActive,
    'joined_on': AppDate.ymd(joinedOn),
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
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Employee && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
