import '../core/error/error_handling_middleware.dart';
import '../core/utils/notification_service.dart';
import '../data/datasources/bluetooth_service.dart';
import '../data/datasources/ikamand_http_service.dart';
import '../data/datasources/local_storage_service.dart';
import '../data/datasources/temperature_database_helper.dart';
import '../data/models/device_model.dart';
import '../data/repositories/cook_program_repository_impl.dart';
import '../data/repositories/cook_session_repository_impl.dart';
import '../data/repositories/device_repository_impl.dart';
import '../data/repositories/preferences_repository_impl.dart';
import '../data/repositories/temperature_repository_impl.dart';
import '../domain/entities/cook_program.dart';
import '../domain/entities/grill_device.dart';
import '../domain/entities/temperature_reading.dart';
import '../domain/usecases/cook_program_executor.dart';
import '../domain/usecases/fan_controller.dart';
import '../domain/usecases/grill_open_detector.dart';

class AppDependencies {
  AppDependencies._({
    required this.notifications,
    required this.errorHandling,
    required this.bluetoothService,
    required this.httpService,
    required this.temperatureDatabaseHelper,
    required this.deviceRepository,
    required this.temperatureRepository,
    required this.cookSessionRepository,
    required this.cookProgramRepository,
    required this.preferencesRepository,
    required this.fanController,
    required this.grillOpenDetector,
    required this.cookProgramExecutor,
  });

  final NotificationService notifications;
  final ErrorHandlingMiddleware errorHandling;
  final BluetoothService bluetoothService;
  final IKamandHttpService httpService;
  final TemperatureDatabaseHelper temperatureDatabaseHelper;
  final DeviceRepositoryImpl deviceRepository;
  final TemperatureRepositoryImpl temperatureRepository;
  final CookSessionRepositoryImpl cookSessionRepository;
  final CookProgramRepositoryImpl cookProgramRepository;
  final PreferencesRepositoryImpl preferencesRepository;
  final FanController fanController;
  final GrillOpenDetector grillOpenDetector;
  final CookProgramExecutor cookProgramExecutor;

  static Future<AppDependencies> create() async {
    await LocalStorageService.initialize();

    final notifications = NotificationService();
    final errorHandling = ErrorHandlingMiddleware(notifications: notifications);
    final bluetoothService = BluetoothService();
    final httpService = IKamandHttpService();
    final temperatureDatabaseHelper = TemperatureDatabaseHelper.instance;
    final deviceRepository = DeviceRepositoryImpl(
      bluetoothService: bluetoothService,
      httpService: httpService,
    );
    final temperatureRepository = TemperatureRepositoryImpl(
      databaseHelper: temperatureDatabaseHelper,
      httpService: httpService,
    );
    final cookSessionRepository = CookSessionRepositoryImpl();
    final cookProgramRepository = CookProgramRepositoryImpl();
    final preferencesRepository = PreferencesRepositoryImpl();
    final fanController = FanController();
    final grillOpenDetector = GrillOpenDetector();
    final cookProgramExecutor =
        CookProgramExecutor(notifications: notifications);

    final dependencies = AppDependencies._(
      notifications: notifications,
      errorHandling: errorHandling,
      bluetoothService: bluetoothService,
      httpService: httpService,
      temperatureDatabaseHelper: temperatureDatabaseHelper,
      deviceRepository: deviceRepository,
      temperatureRepository: temperatureRepository,
      cookSessionRepository: cookSessionRepository,
      cookProgramRepository: cookProgramRepository,
      preferencesRepository: preferencesRepository,
      fanController: fanController,
      grillOpenDetector: grillOpenDetector,
      cookProgramExecutor: cookProgramExecutor,
    );

    await dependencies._seedSampleData();
    return dependencies;
  }

  Future<void> dispose() async {
    notifications.dispose();
    errorHandling.dispose();
    deviceRepository.dispose();
    temperatureRepository.dispose();
    cookSessionRepository.dispose();
    cookProgramRepository.dispose();
    cookProgramExecutor.dispose();
    await LocalStorageService.closeBoxes();
    await temperatureDatabaseHelper.close();
  }

  Future<void> _seedSampleData() async {
    final devicesBox = LocalStorageService.getDevicesBox();
    if (devicesBox.isEmpty) {
      await devicesBox.put(
        'demo-device',
        DeviceModel(
          id: 'demo-device',
          name: 'Backyard Kamand',
          type: DeviceType.unknown.name,
          configuration: const {'demo_mode': true},
        ),
      );
    }

    final existingPrograms = await cookProgramRepository.getAllPrograms();
    if (existingPrograms.isEmpty) {
      await cookProgramRepository.saveProgram(
        const CookProgram(
          id: 'program-low-slow',
          name: 'Low & Slow Brisket',
          stages: [
            CookStage(
              targetTemperature: 225,
              duration: Duration(hours: 6),
              alertOnComplete: true,
            ),
            CookStage(
              targetTemperature: 250,
              duration: Duration(hours: 2),
              alertOnComplete: true,
            ),
          ],
          status: CookProgramStatus.idle,
        ),
      );
      await cookProgramRepository.saveProgram(
        const CookProgram(
          id: 'program-hot-fast',
          name: 'Weeknight Chicken',
          stages: [
            CookStage(
              targetTemperature: 325,
              duration: Duration(minutes: 45),
              alertOnComplete: true,
            ),
            CookStage(
              targetTemperature: 350,
              duration: Duration(minutes: 20),
              alertOnComplete: true,
            ),
          ],
          status: CookProgramStatus.idle,
        ),
      );
    }

    final sessions = await cookSessionRepository.getAllSessions();
    if (sessions.isNotEmpty) {
      return;
    }

    final session = await cookSessionRepository.createSession('demo-device');
    final startTime = DateTime.now().subtract(const Duration(hours: 5));
    final sessionModel = LocalStorageService.getCookSessionsBox().get(session.id);
    if (sessionModel != null) {
      sessionModel.startTime = startTime;
      sessionModel.programId = 'program-low-slow';
      await sessionModel.save();
    }

    for (var index = 0; index < 48; index++) {
      final timestamp = startTime.add(Duration(minutes: index * 5));
      final grillTemp = 205 + (index * 1.4);
      final foodTemp = 55 + (index * 2.6);
      await cookSessionRepository.addReading(
        session.id,
        TemperatureReading(
          probeId: 'demo-device_grill',
          temperature: grillTemp.clamp(180, 255).toDouble(),
          timestamp: timestamp,
          type: ProbeType.grill,
        ),
      );
      await cookSessionRepository.addReading(
        session.id,
        TemperatureReading(
          probeId: 'demo-device_food1',
          temperature: foodTemp.clamp(40, 203).toDouble(),
          timestamp: timestamp,
          type: ProbeType.food1,
        ),
      );
    }

    await cookSessionRepository.endSession(
      session.id,
      'Wrapped after the stall and finished with a pepper-heavy bark.',
    );
    final endedSession = LocalStorageService.getCookSessionsBox().get(session.id);
    if (endedSession != null) {
      endedSession.endTime = startTime.add(const Duration(hours: 4));
      endedSession.programId = 'program-low-slow';
      await endedSession.save();
    }
  }
}
