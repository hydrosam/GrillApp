import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../presentation/bloc/cook_program_bloc.dart';
import '../presentation/bloc/device_connection_bloc.dart';
import '../presentation/bloc/fan_control_bloc.dart';
import '../presentation/bloc/grill_open_detection_bloc.dart';
import '../presentation/bloc/settings_cubit.dart';
import '../presentation/bloc/temperature_monitor_bloc.dart';
import '../presentation/screens/app_shell_screen.dart';
import 'app_dependencies.dart';

class GrillControllerApp extends StatelessWidget {
  const GrillControllerApp({
    super.key,
    required this.dependencies,
  });

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9C4A22),
      brightness: Brightness.light,
      primary: const Color(0xFF9C4A22),
      secondary: const Color(0xFF2F6A49),
      surface: const Color(0xFFFFF9F1),
    );

    return RepositoryProvider<AppDependencies>.value(
      value: dependencies,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => DeviceConnectionBloc(
              repository: dependencies.deviceRepository,
              errorHandling: dependencies.errorHandling,
            ),
          ),
          BlocProvider(
            create: (_) => TemperatureMonitorBloc(
              repository: dependencies.temperatureRepository,
            ),
          ),
          BlocProvider(
            create: (_) => FanControlBloc(
              controller: dependencies.fanController,
              deviceRepository: dependencies.deviceRepository,
              errorHandling: dependencies.errorHandling,
            ),
          ),
          BlocProvider(
            create: (_) => GrillOpenDetectionBloc(
              detector: dependencies.grillOpenDetector,
            ),
          ),
          BlocProvider(
            create: (_) => CookProgramBloc(
              repository: dependencies.cookProgramRepository,
              executor: dependencies.cookProgramExecutor,
              errorHandling: dependencies.errorHandling,
            ),
          ),
          BlocProvider(
            create: (_) => SettingsCubit(
              preferencesRepository: dependencies.preferencesRepository,
            )..load(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Grill Controller',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: colorScheme,
            fontFamily: 'Georgia',
            scaffoldBackgroundColor: const Color(0xFFF4E8D4),
            cardTheme: const CardThemeData(
              color: Color(0xFFFDF7ED),
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFFFFBF5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD9C2A4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFD9C2A4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF9C4A22), width: 2),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C4A22),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: const [
              Breakpoint(start: 0, end: 699, name: MOBILE),
              Breakpoint(start: 700, end: 1099, name: TABLET),
              Breakpoint(start: 1100, end: double.infinity, name: DESKTOP),
            ],
          ),
          home: const AppShellScreen(),
        ),
      ),
    );
  }
}
