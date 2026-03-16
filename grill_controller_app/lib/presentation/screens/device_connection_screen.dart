import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/device_connection_bloc.dart';
import '../widgets/section_card.dart';

class DeviceConnectionScreen extends StatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> {
  final _ssidController = TextEditingController(text: 'BackyardWiFi');
  final _passwordController = TextEditingController();
  final _ipController = TextEditingController(text: '192.168.1.120');

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceConnectionBloc, DeviceConnectionState>(
      builder: (context, state) {
        final selectedDevice = state.selectedDevice;
        return ListView(
          children: [
            SectionCard(
              title: 'Pair a Grill Controller',
              subtitle:
                  'Scan over Bluetooth, then hand the device your WiFi credentials and optional IP for WiFi control.',
              actions: [
                ElevatedButton.icon(
                  onPressed: state is DeviceDiscovering
                      ? null
                      : () => context
                          .read<DeviceConnectionBloc>()
                          .add(const StartDiscovery()),
                  icon: const Icon(Icons.radar),
                  label: Text(
                    state is DeviceDiscovering ? 'Scanning…' : 'Scan',
                  ),
                ),
              ],
              child: Column(
                children: [
                  if (state.devices.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4E7D4),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'No devices discovered yet. Put your controller into pairing mode and tap Scan.',
                      ),
                    )
                  else
                    ...state.devices.map(
                      (device) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: const Color(0xFFE6D4BD)),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFF3DCC2),
                                child: Icon(Icons.outdoor_grill),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      '${device.id}  •  ${device.status.name}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFF806046),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => context
                                    .read<DeviceConnectionBloc>()
                                    .add(ConnectBluetooth(device.id)),
                                child: const Text('Connect'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'WiFi Handoff',
              subtitle:
                  'Once Bluetooth is connected, send network credentials so the grill can move to local WiFi control.',
              child: Column(
                children: [
                  TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: 'WiFi SSID',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'WiFi password',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Device IP (optional but recommended)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selectedDevice == null
                          ? null
                          : () => context.read<DeviceConnectionBloc>().add(
                                SendWifiCredentials(
                                  deviceId: selectedDevice.id,
                                  ssid: _ssidController.text.trim(),
                                  password: _passwordController.text,
                                  deviceIp: _ipController.text.trim(),
                                ),
                              ),
                      icon: const Icon(Icons.wifi),
                      label: Text(
                        selectedDevice == null
                            ? 'Select a device first'
                            : 'Send WiFi Credentials',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'Connection Status',
              subtitle:
                  'The app can stay useful offline, but live control starts once the device reaches WiFi.',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFF9F2E8),
                ),
                child: Text(
                  switch (state) {
                    DeviceDiscovering() => 'Scanning for nearby controllers…',
                    DeviceBluetoothConnected() =>
                      'Bluetooth connected to ${selectedDevice?.name ?? 'device'}. Send WiFi credentials next.',
                    DeviceWifiConnected() =>
                      'WiFi connected to ${selectedDevice?.name ?? 'device'}. Live monitoring is ready.',
                    DeviceConnectionError() =>
                      'Connection error: ${state.message}',
                    DeviceDisconnected() when selectedDevice != null =>
                      '${selectedDevice.name} is disconnected. Reconnect to resume live control.',
                    _ => 'Nothing connected yet.',
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
