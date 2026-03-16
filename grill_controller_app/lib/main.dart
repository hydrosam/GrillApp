import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/grill_controller_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = await AppDependencies.create();

  FlutterError.onError = (details) {
    dependencies.errorHandling.report(
      details.exception,
      details.stack ?? StackTrace.current,
      userMessage: 'A Flutter rendering error was captured.',
      fatal: true,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    dependencies.errorHandling.report(
      error,
      stackTrace,
      userMessage: 'An unexpected platform error was captured.',
      fatal: true,
    );
    return true;
  };

  runApp(GrillControllerApp(dependencies: dependencies));
}
