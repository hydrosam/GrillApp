import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:grill_controller_app/data/models/cook_program_model.dart';
import 'package:grill_controller_app/data/repositories/cook_program_repository_impl.dart';
import 'package:grill_controller_app/domain/entities/cook_program.dart';
import 'dart:io';

void main() {
  late CookProgramRepositoryImpl repository;
  late Directory tempDir;

  setUpAll(() async {
    // Create a temporary directory for Hive
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    
    // Initialize Hive with the temp directory
    Hive.init(tempDir.path);
    
    // Register type adapters
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CookProgramModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(CookStageModelAdapter());
    }
    
    // Open the cook programs box
    await Hive.openBox<CookProgramModel>('cook_programs');
  });

  setUp(() {
    repository = CookProgramRepositoryImpl();
  });

  tearDown(() async {
    // Clear data after each test
    final box = Hive.box<CookProgramModel>('cook_programs');
    await box.clear();
    repository.dispose();
  });

  tearDownAll(() async {
    await Hive.close();
    // Clean up temp directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CookProgramRepository CRUD Operations', () {
    test('should save and retrieve a cook program', () async {
      // Arrange
      final program = CookProgram(
        id: 'test-program-1',
        name: 'Low and Slow Brisket',
        stages: [
          const CookStage(
            targetTemperature: 225.0,
            duration: Duration(hours: 6),
            alertOnComplete: true,
          ),
          const CookStage(
            targetTemperature: 275.0,
            duration: Duration(hours: 2),
            alertOnComplete: true,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      // Act
      await repository.saveProgram(program);
      final retrieved = await repository.getProgram('test-program-1');

      // Assert
      expect(retrieved.id, equals(program.id));
      expect(retrieved.name, equals(program.name));
      expect(retrieved.stages.length, equals(2));
      expect(retrieved.stages[0].targetTemperature, equals(225.0));
      expect(retrieved.stages[0].duration, equals(const Duration(hours: 6)));
      expect(retrieved.stages[1].targetTemperature, equals(275.0));
      expect(retrieved.status, equals(CookProgramStatus.idle));
    });

    test('should update an existing program', () async {
      // Arrange
      final program = CookProgram(
        id: 'test-program-2',
        name: 'Original Name',
        stages: [
          const CookStage(
            targetTemperature: 250.0,
            duration: Duration(hours: 4),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      await repository.saveProgram(program);

      // Act - Update the program
      final updated = CookProgram(
        id: 'test-program-2',
        name: 'Updated Name',
        stages: [
          const CookStage(
            targetTemperature: 275.0,
            duration: Duration(hours: 3),
            alertOnComplete: true,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      await repository.saveProgram(updated);
      final retrieved = await repository.getProgram('test-program-2');

      // Assert
      expect(retrieved.name, equals('Updated Name'));
      expect(retrieved.stages[0].targetTemperature, equals(275.0));
      expect(retrieved.stages[0].duration, equals(const Duration(hours: 3)));
      expect(retrieved.stages[0].alertOnComplete, equals(true));
    });

    test('should retrieve all programs sorted alphabetically', () async {
      // Arrange
      final program1 = CookProgram(
        id: 'prog-1',
        name: 'Zebra Cook',
        stages: [
          const CookStage(
            targetTemperature: 250.0,
            duration: Duration(hours: 2),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      final program2 = CookProgram(
        id: 'prog-2',
        name: 'Apple Cook',
        stages: [
          const CookStage(
            targetTemperature: 300.0,
            duration: Duration(hours: 1),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      final program3 = CookProgram(
        id: 'prog-3',
        name: 'Middle Cook',
        stages: [
          const CookStage(
            targetTemperature: 275.0,
            duration: Duration(hours: 3),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      // Act
      await repository.saveProgram(program1);
      await repository.saveProgram(program2);
      await repository.saveProgram(program3);

      final allPrograms = await repository.getAllPrograms();

      // Assert
      expect(allPrograms.length, equals(3));
      expect(allPrograms[0].name, equals('Apple Cook'));
      expect(allPrograms[1].name, equals('Middle Cook'));
      expect(allPrograms[2].name, equals('Zebra Cook'));
    });

    test('should delete a program', () async {
      // Arrange
      final program = CookProgram(
        id: 'test-program-3',
        name: 'To Be Deleted',
        stages: [
          const CookStage(
            targetTemperature: 250.0,
            duration: Duration(hours: 2),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      await repository.saveProgram(program);

      // Act
      await repository.deleteProgram('test-program-3');

      // Assert
      expect(
        () => repository.getProgram('test-program-3'),
        throwsException,
      );
    });

    test('should update program status', () async {
      // Arrange
      final program = CookProgram(
        id: 'test-program-4',
        name: 'Status Test',
        stages: [
          const CookStage(
            targetTemperature: 250.0,
            duration: Duration(hours: 2),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      await repository.saveProgram(program);

      // Act
      await repository.updateProgramStatus(
        'test-program-4',
        CookProgramStatus.running,
      );

      final retrieved = await repository.getProgram('test-program-4');

      // Assert
      expect(retrieved.status, equals(CookProgramStatus.running));
    });

    test('should duplicate a program with new ID and name', () async {
      // Arrange
      final original = CookProgram(
        id: 'original-program',
        name: 'Original Program',
        stages: [
          const CookStage(
            targetTemperature: 250.0,
            duration: Duration(hours: 4),
            alertOnComplete: true,
          ),
          const CookStage(
            targetTemperature: 300.0,
            duration: Duration(hours: 2),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      await repository.saveProgram(original);

      // Act
      final duplicate = await repository.duplicateProgram(
        'original-program',
        'Duplicated Program',
      );

      // Assert
      expect(duplicate.id, isNot(equals(original.id)));
      expect(duplicate.name, equals('Duplicated Program'));
      expect(duplicate.stages.length, equals(2));
      expect(duplicate.stages[0].targetTemperature, equals(250.0));
      expect(duplicate.stages[1].targetTemperature, equals(300.0));
      expect(duplicate.status, equals(CookProgramStatus.idle));

      // Verify both programs exist
      final allPrograms = await repository.getAllPrograms();
      expect(allPrograms.length, equals(2));
    });

    test('should throw exception when getting non-existent program', () async {
      // Act & Assert
      expect(
        () => repository.getProgram('non-existent-id'),
        throwsException,
      );
    });

    test('should throw exception when updating status of non-existent program',
        () async {
      // Act & Assert
      expect(
        () => repository.updateProgramStatus(
          'non-existent-id',
          CookProgramStatus.running,
        ),
        throwsException,
      );
    });
  });

  group('CookProgramRepository Stream Operations', () {
    test('should emit updates when program is saved', () async {
      // Arrange
      final program = CookProgram(
        id: 'stream-test-1',
        name: 'Stream Test',
        stages: [
          const CookStage(
            targetTemperature: 250.0,
            duration: Duration(hours: 2),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      // Act
      final stream = repository.watchProgram('stream-test-1');
      
      // Save the program after a short delay
      Future.delayed(const Duration(milliseconds: 100), () async {
        await repository.saveProgram(program);
      });

      // Assert
      final emittedProgram = await stream.first;
      expect(emittedProgram.id, equals('stream-test-1'));
      expect(emittedProgram.name, equals('Stream Test'));
    });

    test('should emit updates when program status changes', () async {
      // Arrange
      final program = CookProgram(
        id: 'stream-test-2',
        name: 'Status Stream Test',
        stages: [
          const CookStage(
            targetTemperature: 250.0,
            duration: Duration(hours: 2),
            alertOnComplete: false,
          ),
        ],
        status: CookProgramStatus.idle,
      );

      await repository.saveProgram(program);

      // Act
      final stream = repository.watchProgram('stream-test-2');
      
      // Update status after a short delay
      Future.delayed(const Duration(milliseconds: 100), () async {
        await repository.updateProgramStatus(
          'stream-test-2',
          CookProgramStatus.running,
        );
      });

      // Assert
      final emittedProgram = await stream.first;
      expect(emittedProgram.status, equals(CookProgramStatus.running));
    });
  });
}
