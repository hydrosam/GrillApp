import 'dart:async';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/cook_program.dart';
import '../../domain/repositories/cook_program_repository.dart';
import '../models/cook_program_model.dart';

/// Implementation of CookProgramRepository using Hive
/// 
/// Cook programs are stored in Hive for quick access and persistence.
/// Each program includes multiple stages with temperature and duration settings.
class CookProgramRepositoryImpl implements CookProgramRepository {
  final _uuid = const Uuid();
  final _programStreamControllers = <String, StreamController<CookProgram>>{};
  final String boxName;

  CookProgramRepositoryImpl({this.boxName = 'cook_programs'});

  Box<CookProgramModel> _getBox() {
    return Hive.box<CookProgramModel>(boxName);
  }

  @override
  Future<void> saveProgram(CookProgram program) async {
    final box = _getBox();
    final model = CookProgramModel.fromEntity(program);
    await box.put(program.id, model);

    // Notify stream watchers
    if (_programStreamControllers.containsKey(program.id)) {
      _programStreamControllers[program.id]!.add(program);
    }
  }

  @override
  Future<CookProgram> getProgram(String programId) async {
    final box = _getBox();
    final model = box.get(programId);

    if (model == null) {
      throw Exception('Cook program not found: $programId');
    }

    return model.toEntity();
  }

  @override
  Future<List<CookProgram>> getAllPrograms() async {
    final box = _getBox();
    final models = box.values.toList();

    // Convert to domain entities
    final programs = models.map((model) => model.toEntity()).toList();

    // Sort alphabetically by name
    programs.sort((a, b) => a.name.compareTo(b.name));

    return programs;
  }

  @override
  Future<void> deleteProgram(String programId) async {
    final box = _getBox();
    await box.delete(programId);

    // Close stream controller if exists
    if (_programStreamControllers.containsKey(programId)) {
      await _programStreamControllers[programId]!.close();
      _programStreamControllers.remove(programId);
    }
  }

  @override
  Future<void> updateProgramStatus(
    String programId,
    CookProgramStatus status,
  ) async {
    final box = _getBox();
    final model = box.get(programId);

    if (model == null) {
      throw Exception('Cook program not found: $programId');
    }

    // Update status
    model.status = status.name;
    await model.save();

    // Notify stream watchers
    if (_programStreamControllers.containsKey(programId)) {
      _programStreamControllers[programId]!.add(model.toEntity());
    }
  }

  @override
  Stream<CookProgram> watchProgram(String programId) {
    // Create or reuse stream controller for this program
    if (!_programStreamControllers.containsKey(programId)) {
      _programStreamControllers[programId] =
          StreamController<CookProgram>.broadcast();
    }

    return _programStreamControllers[programId]!.stream;
  }

  @override
  Future<CookProgram> duplicateProgram(
    String programId,
    String newName,
  ) async {
    // Get the original program
    final original = await getProgram(programId);

    // Create a new program with a new ID and name
    final duplicate = CookProgram(
      id: _uuid.v4(),
      name: newName,
      stages: original.stages,
      status: CookProgramStatus.idle,
    );

    // Save the duplicate
    await saveProgram(duplicate);

    return duplicate;
  }

  /// Dispose all stream controllers
  void dispose() {
    for (final controller in _programStreamControllers.values) {
      controller.close();
    }
    _programStreamControllers.clear();
  }
}
