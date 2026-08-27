import 'dart:convert';

const pendingComputerOcrIssue = 'Đang chờ OCR máy tính';

enum ScanQualityLevel { red, yellow, green }

extension ScanQualityLevelValue on ScanQualityLevel {
  String get databaseValue => name.toUpperCase();

  static ScanQualityLevel parse(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'GREEN' => ScanQualityLevel.green,
        'YELLOW' => ScanQualityLevel.yellow,
        _ => ScanQualityLevel.red,
      };
}

enum DrivingLogStatus { draft, verified, exported }

extension DrivingLogStatusValue on DrivingLogStatus {
  String get databaseValue => name.toUpperCase();

  static DrivingLogStatus parse(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'VERIFIED' => DrivingLogStatus.verified,
        'EXPORTED' => DrivingLogStatus.exported,
        _ => DrivingLogStatus.draft,
      };
}

class DrivingLogEntry {
  const DrivingLogEntry({
    required this.id,
    required this.imagePath,
    required this.originalImagePath,
    required this.qualityLevel,
    required this.qualityScore,
    required this.qualityIssues,
    required this.ocrText,
    required this.fieldConfidences,
    required this.voucherDate,
    required this.driverName,
    required this.assistantName,
    required this.vehiclePlate,
    required this.projectAddress,
    required this.tripCount,
    required this.mealCost,
    required this.ruleCost,
    required this.tyreCost,
    required this.otherCost,
    required this.managerConfirmation,
    required this.voucherNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.confirmationId,
    this.confirmedAt,
  });

  final String id;
  final String imagePath;
  final String originalImagePath;
  final ScanQualityLevel qualityLevel;
  final int qualityScore;
  final List<String> qualityIssues;
  final String ocrText;
  final Map<String, double> fieldConfidences;
  final DateTime? voucherDate;
  final String driverName;
  final String assistantName;
  final String vehiclePlate;
  final String projectAddress;
  final int? tripCount;
  final int? mealCost;
  final int? ruleCost;
  final int? tyreCost;
  final int? otherCost;
  final String managerConfirmation;
  final String voucherNumber;
  final DrivingLogStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? confirmationId;
  final DateTime? confirmedAt;

  bool get isConfirmed =>
      confirmationId != null &&
      confirmationId!.isNotEmpty &&
      confirmedAt != null;

  int get totalCost =>
      (mealCost ?? 0) + (ruleCost ?? 0) + (tyreCost ?? 0) + (otherCost ?? 0);

  List<String> get missingFields => [
    if (voucherDate == null) 'Ngày',
    if (driverName.trim().isEmpty) 'Tên lái xe',
    if (projectAddress.trim().isEmpty) 'Tên - địa chỉ công trình',
    if (tripCount == null || tripCount! <= 0) 'Số chuyến',
    if (managerConfirmation.trim().isEmpty) 'Xác nhận người quản lý',
  ];

  bool get hasRequiredOperationalFields =>
      voucherDate != null &&
      driverName.trim().isNotEmpty &&
      projectAddress.trim().isNotEmpty &&
      tripCount != null &&
      tripCount! > 0;

  bool get isComputerOcrPending =>
      qualityIssues.contains(pendingComputerOcrIssue);

  DrivingLogEntry copyWith({
    String? imagePath,
    String? originalImagePath,
    ScanQualityLevel? qualityLevel,
    int? qualityScore,
    List<String>? qualityIssues,
    String? ocrText,
    Map<String, double>? fieldConfidences,
    DateTime? voucherDate,
    bool clearVoucherDate = false,
    String? driverName,
    String? assistantName,
    String? vehiclePlate,
    String? projectAddress,
    int? tripCount,
    bool clearTripCount = false,
    int? mealCost,
    bool clearMealCost = false,
    int? ruleCost,
    bool clearRuleCost = false,
    int? tyreCost,
    bool clearTyreCost = false,
    int? otherCost,
    bool clearOtherCost = false,
    String? managerConfirmation,
    String? voucherNumber,
    DrivingLogStatus? status,
    DateTime? updatedAt,
    String? confirmationId,
    DateTime? confirmedAt,
  }) => DrivingLogEntry(
    id: id,
    imagePath: imagePath ?? this.imagePath,
    originalImagePath: originalImagePath ?? this.originalImagePath,
    qualityLevel: qualityLevel ?? this.qualityLevel,
    qualityScore: qualityScore ?? this.qualityScore,
    qualityIssues: qualityIssues ?? this.qualityIssues,
    ocrText: ocrText ?? this.ocrText,
    fieldConfidences: fieldConfidences ?? this.fieldConfidences,
    voucherDate: clearVoucherDate ? null : (voucherDate ?? this.voucherDate),
    driverName: driverName ?? this.driverName,
    assistantName: assistantName ?? this.assistantName,
    vehiclePlate: vehiclePlate ?? this.vehiclePlate,
    projectAddress: projectAddress ?? this.projectAddress,
    tripCount: clearTripCount ? null : (tripCount ?? this.tripCount),
    mealCost: clearMealCost ? null : (mealCost ?? this.mealCost),
    ruleCost: clearRuleCost ? null : (ruleCost ?? this.ruleCost),
    tyreCost: clearTyreCost ? null : (tyreCost ?? this.tyreCost),
    otherCost: clearOtherCost ? null : (otherCost ?? this.otherCost),
    managerConfirmation: managerConfirmation ?? this.managerConfirmation,
    voucherNumber: voucherNumber ?? this.voucherNumber,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    confirmationId: confirmationId ?? this.confirmationId,
    confirmedAt: confirmedAt ?? this.confirmedAt,
  );

  Map<String, Object?> toDatabase() => {
    'id': id,
    'image_path': imagePath,
    'original_image_path': originalImagePath,
    'quality_level': qualityLevel.databaseValue,
    'quality_score': qualityScore,
    'quality_issues': jsonEncode(qualityIssues),
    'ocr_text': ocrText,
    'field_confidences': jsonEncode(fieldConfidences),
    'voucher_date': voucherDate?.toIso8601String(),
    'driver_name': driverName,
    'assistant_name': assistantName,
    'vehicle_plate': vehiclePlate,
    'project_address': projectAddress,
    'trip_count': tripCount,
    'meal_cost': mealCost,
    'rule_cost': ruleCost,
    'tyre_cost': tyreCost,
    'other_cost': otherCost,
    'manager_confirmation': managerConfirmation,
    'voucher_number': voucherNumber,
    'status': status.databaseValue,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'confirmation_id': confirmationId,
    'confirmed_at': confirmedAt?.toIso8601String(),
  };

  factory DrivingLogEntry.fromDatabase(Map<String, Object?> row) {
    final issues = jsonDecode(row['quality_issues']?.toString() ?? '[]');
    final confidence = jsonDecode(row['field_confidences']?.toString() ?? '{}');
    return DrivingLogEntry(
      id: row['id']!.toString(),
      imagePath: row['image_path']?.toString() ?? '',
      originalImagePath: row['original_image_path']?.toString() ?? '',
      qualityLevel: ScanQualityLevelValue.parse(row['quality_level']),
      qualityScore: (row['quality_score'] as num?)?.round() ?? 0,
      qualityIssues: (issues as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      ocrText: row['ocr_text']?.toString() ?? '',
      fieldConfidences: (confidence as Map? ?? const {}).map(
        (key, value) =>
            MapEntry(key.toString(), value is num ? value.toDouble() : 0),
      ),
      voucherDate: DateTime.tryParse(row['voucher_date']?.toString() ?? ''),
      driverName: row['driver_name']?.toString() ?? '',
      assistantName: row['assistant_name']?.toString() ?? '',
      vehiclePlate: row['vehicle_plate']?.toString() ?? '',
      projectAddress: row['project_address']?.toString() ?? '',
      tripCount: (row['trip_count'] as num?)?.round(),
      mealCost: (row['meal_cost'] as num?)?.round(),
      ruleCost: (row['rule_cost'] as num?)?.round(),
      tyreCost: (row['tyre_cost'] as num?)?.round(),
      otherCost: (row['other_cost'] as num?)?.round(),
      managerConfirmation: row['manager_confirmation']?.toString() ?? '',
      voucherNumber: row['voucher_number']?.toString() ?? '',
      status: DrivingLogStatusValue.parse(row['status']),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      confirmationId: row['confirmation_id']?.toString(),
      confirmedAt: DateTime.tryParse(row['confirmed_at']?.toString() ?? ''),
    );
  }
}
