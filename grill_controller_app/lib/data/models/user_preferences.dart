/// User preferences and app settings
class UserPreferences {
  final String grillType;
  final String temperatureUnit; // 'F' or 'C'
  final Map<String, dynamic>? fanSpeedCurveAdjustments;

  const UserPreferences({
    required this.grillType,
    this.temperatureUnit = 'F',
    this.fanSpeedCurveAdjustments,
  });

  Map<String, dynamic> toJson() {
    return {
      'grillType': grillType,
      'temperatureUnit': temperatureUnit,
      'fanSpeedCurveAdjustments': fanSpeedCurveAdjustments,
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      grillType: json['grillType'] as String? ?? 'standard',
      temperatureUnit: json['temperatureUnit'] as String? ?? 'F',
      fanSpeedCurveAdjustments: json['fanSpeedCurveAdjustments'] as Map<String, dynamic>?,
    );
  }

  factory UserPreferences.defaultPreferences() {
    return const UserPreferences(
      grillType: 'standard',
      temperatureUnit: 'F',
    );
  }

  UserPreferences copyWith({
    String? grillType,
    String? temperatureUnit,
    Map<String, dynamic>? fanSpeedCurveAdjustments,
  }) {
    return UserPreferences(
      grillType: grillType ?? this.grillType,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      fanSpeedCurveAdjustments: fanSpeedCurveAdjustments ?? this.fanSpeedCurveAdjustments,
    );
  }
}
