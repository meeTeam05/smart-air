import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_theme.dart';
import '../../services/ble_models.dart';
import '../../services/ble_service.dart';

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key, required this.homeId});
  final String homeId;

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  final _bleService = BleService();
  final List<BleDeviceInfo> _discovered = [];
  bool _scanning = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bleService.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    final ok = await _bleService.ensurePermissions();
    if (!ok || !mounted) return;

    setState(() {
      _scanning = true;
      _discovered.clear();
    });

    _sub = _bleService.scan().listen((device) {
      if (!mounted) return;
      setState(() {
        if (!_discovered.any((d) => d.remoteId == device.remoteId)) {
          _discovered.add(device);
        }
      });
    });

    await Future.delayed(const Duration(seconds: 10));
    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text('Add Device', style: TextStyle(color: c.textPrimary)),
        backgroundColor: c.bg,
        elevation: 0,
        actions: [
          if (!_scanning)
            TextButton(
              onPressed: _startScan,
              child: const Text('Scan Again'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_scanning)
            LinearProgressIndicator(
              backgroundColor: c.surface,
              color: AppColors.primary,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _scanning
                  ? 'Scanning for Smart Air devices…'
                  : 'Found ${_discovered.length} device(s)',
              style: TextStyle(color: c.textSecondary),
            ),
          ),
          Expanded(
            child: _discovered.isEmpty && !_scanning
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_searching,
                            size: 64, color: c.textSecondary),
                        const SizedBox(height: 12),
                        Text('No devices found',
                            style: TextStyle(color: c.textSecondary)),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _startScan,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _discovered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = _discovered[i];
                      return ListTile(
                        tileColor: c.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        leading: const Icon(Icons.bluetooth,
                            color: AppColors.primary),
                        title: Text(d.name.isNotEmpty ? d.name : 'Unknown',
                            style: TextStyle(color: c.textPrimary)),
                        subtitle: Text(d.remoteId,
                            style: TextStyle(color: c.textSecondary)),
                        onTap: () => context.push(
                          '/provision/wifi?homeId=${widget.homeId}&mac=${Uri.encodeComponent(d.remoteId)}',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
