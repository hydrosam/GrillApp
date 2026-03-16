import 'dart:async';

import 'package:uuid/uuid.dart';

import 'app_notification.dart';

class NotificationService {
  final _uuid = const Uuid();
  final StreamController<AppNotification> _controller =
      StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get stream => _controller.stream;

  AppNotification push({
    required String title,
    required String message,
    AppNotificationType type = AppNotificationType.info,
  }) {
    final notification = AppNotification(
      id: _uuid.v4(),
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
    );

    if (!_controller.isClosed) {
      _controller.add(notification);
    }

    return notification;
  }

  void dispose() {
    _controller.close();
  }
}
