import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/error_handling_middleware.dart';
import '../../data/repositories/device_repository_impl.dart';
import '../../domain/entities/fan_status.dart';
import '../../domain/entities/grill_device.dart';
import '../../domain/repositories/device_repository.dart';

abstract class DeviceConnectionEvent extends Equatable {
  const DeviceConnectionEvent();

  @override
  List<Object?> get props => [];
}

class StartDiscovery extends DeviceConnectionEvent {
  const StartDiscovery();
}

class ConnectBluetooth extends DeviceConnectionEvent {
  final String deviceId;

  const ConnectBluetooth(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

class SendWifiCredentials extends DeviceConnectionEvent {
  final String deviceId;
  final String ssid;
  final String password;
  final String? deviceIp;

  const SendWifiCredentials({
    required this.deviceId,
    required this.ssid,
    required this.password,
    this.deviceIp,
  });

  @override
  List<Object?> get props => [deviceId, ssid, password, deviceIp];
}

class DisconnectDevice extends DeviceConnectionEvent {
  final String deviceId;

  const DisconnectDevice(this.deviceId);

  @override
  List<Object?> get props => [deviceId];
}

abstract class DeviceConnectionState extends Equatable {
  final List<GrillDevice> devices;
  final GrillDevice? selectedDevice;
  final String? message;

  const DeviceConnectionState({
    required this.devices,
    this.selectedDevice,
    this.message,
  });

  @override
  List<Object?> get props => [devices, selectedDevice, message];
}

class DeviceDisconnected extends DeviceConnectionState {
  const DeviceDisconnected({
    List<GrillDevice> devices = const [],
    GrillDevice? selectedDevice,
    String? message,
  }) : super(devices: devices, selectedDevice: selectedDevice, message: message);
}

class DeviceDiscovering extends DeviceConnectionState {
  const DeviceDiscovering({
    required super.devices,
    super.selectedDevice,
    super.message,
  });
}

class DeviceBluetoothConnected extends DeviceConnectionState {
  const DeviceBluetoothConnected({
    required super.devices,
    required super.selectedDevice,
    super.message,
  });
}

class DeviceWifiConnected extends DeviceConnectionState {
  const DeviceWifiConnected({
    required super.devices,
    required super.selectedDevice,
    super.message,
  });
}

class DeviceConnectionError extends DeviceConnectionState {
  const DeviceConnectionError({
    required super.devices,
    super.selectedDevice,
    required super.message,
  });
}

class DeviceConnectionBloc
    extends Bloc<DeviceConnectionEvent, DeviceConnectionState> {
  DeviceConnectionBloc({
    required DeviceRepository repository,
    required ErrorHandlingMiddleware errorHandling,
  })  : _repository = repository,
        _errorHandling = errorHandling,
        super(const DeviceDisconnected()) {
    on<StartDiscovery>(_onStartDiscovery);
    on<ConnectBluetooth>(_onConnectBluetooth);
    on<SendWifiCredentials>(_onSendWifiCredentials);
    on<DisconnectDevice>(_onDisconnectDevice);
  }

  final DeviceRepository _repository;
  final ErrorHandlingMiddleware _errorHandling;

  Future<void> _onStartDiscovery(
    StartDiscovery event,
    Emitter<DeviceConnectionState> emit,
  ) async {
    emit(DeviceDiscovering(
      devices: state.devices,
      selectedDevice: state.selectedDevice,
    ));

    try {
      final devices = await _errorHandling.guard(
        () => _repository.discoverDevices(),
        userMessage: 'Bluetooth discovery failed. Check permissions and try again.',
      );
      emit(DeviceDisconnected(devices: devices));
    } catch (error) {
      emit(DeviceConnectionError(
        devices: state.devices,
        selectedDevice: state.selectedDevice,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onConnectBluetooth(
    ConnectBluetooth event,
    Emitter<DeviceConnectionState> emit,
  ) async {
    try {
      await _errorHandling.guard(
        () => _repository.connectBluetooth(event.deviceId),
        userMessage: 'Could not connect over Bluetooth.',
      );
      final selected = _findDevice(event.deviceId)?.copyWith(
            status: ConnectionStatus.bluetooth,
          ) ??
          _fallbackDevice(event.deviceId).copyWith(
            status: ConnectionStatus.bluetooth,
          );
      emit(DeviceBluetoothConnected(
        devices: _replaceDevice(selected),
        selectedDevice: selected,
      ));
    } catch (error) {
      emit(DeviceConnectionError(
        devices: state.devices,
        selectedDevice: state.selectedDevice,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onSendWifiCredentials(
    SendWifiCredentials event,
    Emitter<DeviceConnectionState> emit,
  ) async {
    try {
      await _errorHandling.guard(
        () => _repository.sendWifiCredentials(
          event.deviceId,
          event.ssid,
          event.password,
        ),
        userMessage: 'Could not send WiFi credentials to the device.',
      );

      GrillDevice selected = _findDevice(event.deviceId)?.copyWith(
            status: ConnectionStatus.wifi,
          ) ??
          _fallbackDevice(event.deviceId).copyWith(
            status: ConnectionStatus.wifi,
          );

      if (_repository is DeviceRepositoryImpl &&
          event.deviceIp != null &&
          event.deviceIp!.trim().isNotEmpty) {
        final impl = _repository as DeviceRepositoryImpl;
        await _errorHandling.guard(
          () => impl.updateDeviceIp(event.deviceId, event.deviceIp!.trim()),
          userMessage:
              'The device could not be reached on WiFi. Verify the IP address and try again.',
        );
        try {
          selected = await _repository.watchDevice(event.deviceId).first.timeout(
                const Duration(seconds: 2),
              );
        } catch (_) {
          selected = selected.copyWith(status: ConnectionStatus.wifi);
        }
      }

      emit(DeviceWifiConnected(
        devices: _replaceDevice(selected),
        selectedDevice: selected,
      ));
    } catch (error) {
      emit(DeviceConnectionError(
        devices: state.devices,
        selectedDevice: state.selectedDevice,
        message: error.toString(),
      ));
    }
  }

  Future<void> _onDisconnectDevice(
    DisconnectDevice event,
    Emitter<DeviceConnectionState> emit,
  ) async {
    try {
      await _errorHandling.guard(
        () => _repository.disconnect(event.deviceId),
        userMessage: 'Could not disconnect from the device cleanly.',
      );
      final disconnected = _findDevice(event.deviceId)?.copyWith(
            status: ConnectionStatus.disconnected,
          ) ??
          _fallbackDevice(event.deviceId);
      emit(DeviceDisconnected(
        devices: _replaceDevice(disconnected),
        selectedDevice: disconnected,
      ));
    } catch (error) {
      emit(DeviceConnectionError(
        devices: state.devices,
        selectedDevice: state.selectedDevice,
        message: error.toString(),
      ));
    }
  }

  GrillDevice? _findDevice(String deviceId) {
    for (final device in state.devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  List<GrillDevice> _replaceDevice(GrillDevice selected) {
    final devices = [...state.devices];
    final index = devices.indexWhere((device) => device.id == selected.id);
    if (index == -1) {
      devices.add(selected);
    } else {
      devices[index] = selected;
    }
    return devices;
  }

  GrillDevice _fallbackDevice(String deviceId) {
    return GrillDevice(
      id: deviceId,
      name: 'Grill Device',
      type: DeviceType.unknown,
      status: ConnectionStatus.disconnected,
      probes: const [],
      fanStatus: FanStatus(
        speed: 0,
        isAutomatic: true,
        lastUpdate: DateTime.now(),
      ),
    );
  }
}
