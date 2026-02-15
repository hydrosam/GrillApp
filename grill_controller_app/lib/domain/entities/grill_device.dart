import 'package:equatable/equatable.dart';
import 'probe.dart';
import 'fan_status.dart';

enum DeviceType { ikamand, unknown }

enum ConnectionStatus { disconnected, bluetooth, wifi }

/// Device representation
class GrillDevice extends Equatable {
  final String id;
  final String name;
  final DeviceType type;
  final ConnectionStatus status;
  final List<Probe> probes;
  final FanStatus fanStatus;

  const GrillDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.probes,
    required this.fanStatus,
  });

  @override
  List<Object?> get props => [id, name, type, status, probes, fanStatus];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'status': status.name,
      'probes': probes.map((p) => p.toJson()).toList(),
      'fanStatus': fanStatus.toJson(),
    };
  }

  factory GrillDevice.fromJson(Map<String, dynamic> json) {
    return GrillDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DeviceType.values.firstWhere((e) => e.name == json['type']),
      status: ConnectionStatus.values.firstWhere((e) => e.name == json['status']),
      probes: (json['probes'] as List)
          .map((p) => Probe.fromJson(p as Map<String, dynamic>))
          .toList(),
      fanStatus: FanStatus.fromJson(json['fanStatus'] as Map<String, dynamic>),
    );
  }
}
