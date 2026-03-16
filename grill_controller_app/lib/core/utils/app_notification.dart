import 'package:equatable/equatable.dart';

enum AppNotificationType { info, success, warning, error, alert }

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime timestamp;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, title, message, type, timestamp];
}
