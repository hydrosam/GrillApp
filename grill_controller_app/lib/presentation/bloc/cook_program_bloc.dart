import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/error_handling_middleware.dart';
import '../../domain/entities/cook_program.dart';
import '../../domain/repositories/cook_program_repository.dart';
import '../../domain/usecases/cook_program_executor.dart';

abstract class CookProgramEvent extends Equatable {
  const CookProgramEvent();

  @override
  List<Object?> get props => [];
}

class LoadPrograms extends CookProgramEvent {
  const LoadPrograms();
}

class SaveProgram extends CookProgramEvent {
  final CookProgram program;

  const SaveProgram(this.program);

  @override
  List<Object?> get props => [program];
}

class DeleteProgram extends CookProgramEvent {
  final String programId;

  const DeleteProgram(this.programId);

  @override
  List<Object?> get props => [programId];
}

class DuplicateProgram extends CookProgramEvent {
  final String programId;
  final String newName;

  const DuplicateProgram({
    required this.programId,
    required this.newName,
  });

  @override
  List<Object?> get props => [programId, newName];
}

class StartProgram extends CookProgramEvent {
  final String programId;

  const StartProgram(this.programId);

  @override
  List<Object?> get props => [programId];
}

class PauseProgram extends CookProgramEvent {
  const PauseProgram();
}

class ResumeProgram extends CookProgramEvent {
  const ResumeProgram();
}

class StopProgram extends CookProgramEvent {
  const StopProgram();
}

class StageComplete extends CookProgramEvent {
  const StageComplete();
}

class ObserveProgramTemperature extends CookProgramEvent {
  final double currentTemperature;

  const ObserveProgramTemperature(this.currentTemperature);

  @override
  List<Object?> get props => [currentTemperature];
}

class ProgramExecutionUpdated extends CookProgramEvent {
  final CookProgramExecutionSnapshot snapshot;

  const ProgramExecutionUpdated(this.snapshot);

  @override
  List<Object?> get props => [snapshot];
}

abstract class CookProgramState extends Equatable {
  final List<CookProgram> programs;
  final CookProgramExecutionSnapshot? execution;
  final String? message;

  const CookProgramState({
    required this.programs,
    this.execution,
    this.message,
  });

  @override
  List<Object?> get props => [programs, execution, message];
}

class CookProgramIdle extends CookProgramState {
  const CookProgramIdle({
    List<CookProgram> programs = const [],
    CookProgramExecutionSnapshot? execution,
    String? message,
  }) : super(programs: programs, execution: execution, message: message);
}

class CookProgramRunning extends CookProgramState {
  const CookProgramRunning({
    required super.programs,
    required super.execution,
    super.message,
  });
}

class CookProgramPaused extends CookProgramState {
  const CookProgramPaused({
    required super.programs,
    required super.execution,
    super.message,
  });
}

class CookProgramCompleted extends CookProgramState {
  const CookProgramCompleted({
    required super.programs,
    required super.execution,
    super.message,
  });
}

class CookProgramError extends CookProgramState {
  const CookProgramError({
    required super.programs,
    super.execution,
    required super.message,
  });
}

class CookProgramBloc extends Bloc<CookProgramEvent, CookProgramState> {
  CookProgramBloc({
    required CookProgramRepository repository,
    required CookProgramExecutor executor,
    required ErrorHandlingMiddleware errorHandling,
  })  : _repository = repository,
        _executor = executor,
        _errorHandling = errorHandling,
        super(const CookProgramIdle()) {
    on<LoadPrograms>(_onLoadPrograms);
    on<SaveProgram>(_onSaveProgram);
    on<DeleteProgram>(_onDeleteProgram);
    on<DuplicateProgram>(_onDuplicateProgram);
    on<StartProgram>(_onStartProgram);
    on<PauseProgram>(_onPauseProgram);
    on<ResumeProgram>(_onResumeProgram);
    on<StopProgram>(_onStopProgram);
    on<StageComplete>(_onStageComplete);
    on<ObserveProgramTemperature>(_onObserveTemperature);
    on<ProgramExecutionUpdated>(_onProgramExecutionUpdated);

    _executionSubscription = _executor.stream.listen(
      (snapshot) => add(ProgramExecutionUpdated(snapshot)),
    );
  }

  final CookProgramRepository _repository;
  final CookProgramExecutor _executor;
  final ErrorHandlingMiddleware _errorHandling;
  late final StreamSubscription<CookProgramExecutionSnapshot>
      _executionSubscription;

  Future<void> _onLoadPrograms(
    LoadPrograms event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      final programs = await _errorHandling.guard(
        _repository.getAllPrograms,
        userMessage: 'Could not load saved cook programs.',
      );
      emit(CookProgramIdle(programs: programs, execution: state.execution));
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onSaveProgram(
    SaveProgram event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      await _errorHandling.guard(
        () => _repository.saveProgram(event.program),
        userMessage: 'Could not save the cook program.',
      );
      add(const LoadPrograms());
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onDeleteProgram(
    DeleteProgram event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      await _errorHandling.guard(
        () => _repository.deleteProgram(event.programId),
        userMessage: 'Could not delete that cook program.',
      );
      add(const LoadPrograms());
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onDuplicateProgram(
    DuplicateProgram event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      await _errorHandling.guard(
        () => _repository.duplicateProgram(event.programId, event.newName),
        userMessage: 'Could not duplicate that cook program.',
      );
      add(const LoadPrograms());
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onStartProgram(
    StartProgram event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      final program = await _errorHandling.guard(
        () => _repository.getProgram(event.programId),
        userMessage: 'Could not load the selected cook program.',
      );
      await _repository.updateProgramStatus(
        event.programId,
        CookProgramStatus.running,
      );
      final execution = _executor.start(program);
      final programs = await _loadProgramsWithExecution(execution);
      emit(CookProgramRunning(programs: programs, execution: execution));
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onPauseProgram(
    PauseProgram event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      final execution = _executor.pause();
      await _repository.updateProgramStatus(
        execution.program.id,
        CookProgramStatus.paused,
      );
      final programs = await _loadProgramsWithExecution(execution);
      emit(CookProgramPaused(programs: programs, execution: execution));
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onResumeProgram(
    ResumeProgram event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      final execution = _executor.resume();
      await _repository.updateProgramStatus(
        execution.program.id,
        CookProgramStatus.running,
      );
      final programs = await _loadProgramsWithExecution(execution);
      emit(CookProgramRunning(programs: programs, execution: execution));
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onStopProgram(
    StopProgram event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      final execution = _executor.stop();
      await _repository.updateProgramStatus(
        execution.program.id,
        CookProgramStatus.idle,
      );
      final programs = await _loadProgramsWithExecution(execution);
      emit(CookProgramIdle(programs: programs, execution: execution));
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onStageComplete(
    StageComplete event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      final execution = _executor.completeCurrentStage();
      final programs = await _loadProgramsWithExecution(execution);
      emit(_mapState(programs, execution));
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  void _onObserveTemperature(
    ObserveProgramTemperature event,
    Emitter<CookProgramState> emit,
  ) {
    try {
      _executor.onTemperatureUpdate(event.currentTemperature);
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onProgramExecutionUpdated(
    ProgramExecutionUpdated event,
    Emitter<CookProgramState> emit,
  ) async {
    try {
      final status = switch (event.snapshot.status) {
        CookProgramExecutionStatus.running => CookProgramStatus.running,
        CookProgramExecutionStatus.paused => CookProgramStatus.paused,
        CookProgramExecutionStatus.completed => CookProgramStatus.completed,
        CookProgramExecutionStatus.idle || CookProgramExecutionStatus.stopped =>
          CookProgramStatus.idle,
      };
      await _repository.updateProgramStatus(event.snapshot.program.id, status);
      final programs = await _loadProgramsWithExecution(event.snapshot);
      emit(_mapState(programs, event.snapshot));
    } catch (error) {
      emit(CookProgramError(
        programs: state.programs,
        execution: state.execution,
        message: error.toString(),
      ));
    }
  }

  Future<List<CookProgram>> _loadProgramsWithExecution(
    CookProgramExecutionSnapshot execution,
  ) async {
    final programs = await _repository.getAllPrograms();
    final index = programs.indexWhere((program) => program.id == execution.program.id);
    if (index == -1) {
      return programs;
    }

    final synced = [...programs];
    synced[index] = execution.program;
    return synced;
  }

  CookProgramState _mapState(
    List<CookProgram> programs,
    CookProgramExecutionSnapshot execution,
  ) {
    return switch (execution.status) {
      CookProgramExecutionStatus.running => CookProgramRunning(
          programs: programs,
          execution: execution,
        ),
      CookProgramExecutionStatus.paused => CookProgramPaused(
          programs: programs,
          execution: execution,
        ),
      CookProgramExecutionStatus.completed => CookProgramCompleted(
          programs: programs,
          execution: execution,
        ),
      CookProgramExecutionStatus.idle || CookProgramExecutionStatus.stopped =>
        CookProgramIdle(
          programs: programs,
          execution: execution,
        ),
    };
  }

  @override
  Future<void> close() async {
    await _executionSubscription.cancel();
    return super.close();
  }
}
