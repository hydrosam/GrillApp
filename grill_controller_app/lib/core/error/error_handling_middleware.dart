import 'dart:async';

import 'package:equatable/equatable.dart';

import '../utils/app_notification.dart';
import '../utils/notification_service.dart';

class ErrorRecord extends Equatable {
  final Object error;
  final StackTrace stackTrace;
  final DateTime timestamp;
  final bool fatal;

  const ErrorRecord({
    required this.error,
    required this.stackTrace,
    required this.timestamp,
    required this.fatal,
  });

  @override
  List<Object?> get props => [error, stackTrace, timestamp, fatal];
}

class ErrorHandlingMiddleware {
  ErrorHandlingMiddleware({required NotificationService notifications})
      : _notifications = notifications;

  final NotificationService _notifications;
  final StreamController<ErrorRecord> _errors =
      StreamController<ErrorRecord>.broadcast();

  Stream<ErrorRecord> get errors => _errors.stream;

  Future<T> guard<T>(
    Future<T> Function() action, {
    required String userMessage,
    bool fatal = false,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      report(
        error,
        stackTrace,
        userMessage: userMessage,
        fatal: fatal,
      );
      rethrow;
    }
  }

  void report(
    Object error,
    StackTrace stackTrace, {
    required String userMessage,
    bool fatal = false,
  }) {
    final record = ErrorRecord(
      error: error,
      stackTrace: stackTrace,
      timestamp: DateTime.now(),
      fatal: fatal,
    );

    if (!_errors.isClosed) {
      _errors.add(record);
    }

    _notifications.push(
      title: fatal ? 'Critical Error' : 'Something went wrong',
      message: userMessage,
      type: fatal ? AppNotificationType.error : AppNotificationType.warning,
    );
  }

  void dispose() {
    _errors.close();
  }
}
