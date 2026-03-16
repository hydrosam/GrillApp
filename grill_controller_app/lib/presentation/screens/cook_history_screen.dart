import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/utils/session_share_service.dart';
import '../../domain/entities/cook_session.dart';
import '../widgets/section_card.dart';
import '../widgets/temperature_chart.dart';

class CookHistoryScreen extends StatefulWidget {
  const CookHistoryScreen({
    super.key,
    required this.deviceId,
  });

  final String? deviceId;

  @override
  State<CookHistoryScreen> createState() => _CookHistoryScreenState();
}

class _CookHistoryScreenState extends State<CookHistoryScreen> {
  late Future<List<CookSession>> _sessionsFuture;
  final _shareService = SessionShareService();
  String? _selectedSessionId;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant CookHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.deviceId != oldWidget.deviceId) {
      _reload();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CookSession>>(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <CookSession>[];
        final selected = _selectedSession(
          sessions,
        );

        if (selected != null && _notesController.text != (selected.notes ?? '')) {
          _notesController.text = selected.notes ?? '';
        }

        return ListView(
          children: [
            SectionCard(
              title: 'Cook History',
              subtitle:
                  'Browse saved sessions, revisit temperature curves, and keep notes that make the next cook smarter.',
              child: sessions.isEmpty
                  ? const Text('No saved sessions yet.')
                  : Column(
                      children: sessions
                          .map(
                            (session) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              selected: session.id == selected?.id,
                              title: Text(session.program?.name ?? 'Manual cook'),
                              subtitle: Text(
                                '${session.startTime.month}/${session.startTime.day}/${session.startTime.year} • ${_durationLabel(session)}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => setState(() {
                                _selectedSessionId = session.id;
                              }),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 18),
            if (selected != null)
              SectionCard(
                title: selected.program?.name ?? 'Session detail',
                subtitle:
                    'Temperature history, notes, and sharing tools stay attached to each completed cook.',
                actions: [
                  OutlinedButton.icon(
                    onPressed: () => _shareSession(selected, false),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share Card'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _shareSession(selected, true),
                    icon: const Icon(Icons.layers),
                    label: const Text('Overlay PNG'),
                  ),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Chip(label: Text('Device ${selected.deviceId}')),
                        Chip(label: Text(_durationLabel(selected))),
                        if (selected.program != null)
                          Chip(label: Text('${selected.program!.stages.length} stages')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TemperatureChart(readings: selected.readings),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Cook notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => _saveNotes(selected),
                          child: const Text('Save Notes'),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => _deleteSession(selected),
                          child: const Text('Delete Session'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  AppDependencies get _dependencies => context.read<AppDependencies>();

  void _reload() {
    final repo = _dependencies.cookSessionRepository;
    _sessionsFuture = widget.deviceId == null
        ? repo.getAllSessions()
        : repo.getSessionsForDevice(widget.deviceId!);
  }

  CookSession? _selectedSession(List<CookSession> sessions) {
    if (sessions.isEmpty) {
      return null;
    }
    return sessions.firstWhere(
      (session) => session.id == _selectedSessionId,
      orElse: () => sessions.first,
    );
  }

  String _durationLabel(CookSession session) {
    final duration =
        (session.endTime ?? DateTime.now()).difference(session.startTime);
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }

  Future<void> _saveNotes(CookSession session) async {
    await _dependencies.cookSessionRepository
        .updateNotes(session.id, _notesController.text);
    setState(_reload);
  }

  Future<void> _deleteSession(CookSession session) async {
    await _dependencies.cookSessionRepository.deleteSession(session.id);
    setState(() {
      _selectedSessionId = null;
      _reload();
    });
  }

  Future<void> _shareSession(
    CookSession session,
    bool transparentBackground,
  ) async {
    await _shareService.share(
      session,
      transparentBackground: transparentBackground,
    );
  }
}
