import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../app_theme.dart';
import '../services/ble_models.dart';

// GATT UUIDs — must match firmware ble_prov.c
const _kProvSvcUuid = '0000fffe-0000-1000-8000-00805f9b34fb';
const _kSsidUuid    = '0000ff01-0000-1000-8000-00805f9b34fb';
const _kPassUuid    = '0000ff02-0000-1000-8000-00805f9b34fb';
const _kStatusUuid  = '0000ff03-0000-1000-8000-00805f9b34fb';

// Native channel to open Android Location Settings
const _settingsChannel = MethodChannel('mt_home/settings');

/// WiFi credential screen shown after BLE connection.
/// Scans real nearby WiFi networks from the phone.
class WifiSetupScreen extends StatefulWidget {
  final BleDeviceInfo device;
  final SensorSnapshot? snapshot;

  const WifiSetupScreen({
    super.key,
    required this.device,
    this.snapshot,
  });

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isSending = false;
  bool _isLoadingNetworks = false;
  bool _isPickerOpen = false; // guard against double bottom sheets
  StateSetter? _sheetSetState; // lets _scanNetworks rebuild the open sheet
  String _selectedSsid = '';
  List<WiFiAccessPoint> _networks = [];
  String? _scanError;

  // BLE provisioning state
  StreamSubscription<List<int>>? _notifySub;
  String? _submitError;
  BluetoothDevice? _bleDevice;

  AppPalette get c => context.colors;

  @override
  void initState() {
    super.initState();
    _scanNetworks();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _notifySub?.cancel();
    _bleDevice?.disconnect().ignore();
    super.dispose();
  }

  // ── Open Android Location Settings ──────────────────────────────────────────

  Future<void> _openLocationSettings() async {
    try {
      await _settingsChannel.invokeMethod('openLocationSettings');
    } catch (_) {
      // Fallback: open app settings if native channel fails
      await openAppSettings();
    }
  }

  // ── WiFi scan ────────────────────────────────────────────────────────────────

  Future<void> _scanNetworks() async {
    setState(() {
      _isLoadingNetworks = true;
      _scanError = null;
    });

    try {
      // ① Request location permission (required by Android for WiFi scan)
      final locStatus = await Permission.locationWhenInUse.request();
      if (!locStatus.isGranted) {
        if (mounted) {
          setState(() {
            _isLoadingNetworks = false;
            _scanError =
                'Location permission is required to scan Wi-Fi networks.\n'
                'Please grant it in app settings.';
          });
        }
        return;
      }

      // ② Try to trigger a new scan (may fail on Android 9+, that's OK)
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        await Future.delayed(const Duration(seconds: 2));
      }

      // ③ Always attempt to fetch results from system cache
      //    even if canStartScan returned notSupported / failed
      List<WiFiAccessPoint> results = [];
      final canGet = await WiFiScan.instance.canGetScannedResults();
      if (canGet == CanGetScannedResults.yes) {
        results = await WiFiScan.instance.getScannedResults();
      }

      if (mounted) {
        final seen = <String>{};
        final newNetworks = results
            .where((ap) => ap.ssid.isNotEmpty && seen.add(ap.ssid))
            .toList()
          ..sort((a, b) => b.level.compareTo(a.level));
        String? newError;
        if (newNetworks.isEmpty) {
          if (canGet == CanGetScannedResults.noLocationServiceDisabled) {
            newError = 'noLocationServiceDisabled';
          } else if (canGet != CanGetScannedResults.yes) {
            newError =
                'Unable to read Wi-Fi results (${canGet.name}).\n'
                'Make sure Location is enabled in device Settings.';
          }
        }
        // Update parent state
        setState(() {
          _networks = newNetworks;
          _isLoadingNetworks = false;
          _scanError = newError;
        });
        // Also push update into open bottom sheet (different route)
        _sheetSetState?.call(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanError = 'Scan error: $e');
      }
    }

    if (mounted) setState(() => _isLoadingNetworks = false);
    // Push final state to sheet if still open
    _sheetSetState?.call(() {});
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Wi-Fi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Device only supports 2.4 GHz Wi-Fi networks',
                      style:
                          TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    _buildNetworkField(),
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                    const SizedBox(height: 16),
                    _buildWarning(),
                    const SizedBox(height: 32),
                    _buildConnectButton(),
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submitError!,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.red, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: c.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.device.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Network selector field ───────────────────────────────────────────────────

  Widget _buildNetworkField() {
    return GestureDetector(
      onTap: _showNetworkPicker,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedSsid.isNotEmpty
                ? AppColors.primary
                : c.border,
            width: _selectedSsid.isNotEmpty ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.wifi,
              color: _selectedSsid.isNotEmpty
                  ? AppColors.primary
                  : c.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedSsid.isEmpty
                    ? 'Select Wi-Fi network'
                    : _selectedSsid,
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedSsid.isEmpty
                      ? c.textSecondary
                      : c.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: _showNetworkPicker,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(80, 32),
              ),
              child: const Text(
                'Select Wi-Fi',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Password field ───────────────────────────────────────────────────────────

  Widget _buildPasswordField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: c.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              style: TextStyle(fontSize: 15, color: c.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Password',
                hintStyle: TextStyle(color: c.textSecondary),
              ),
            ),
          ),
          GestureDetector(
            onTap: () =>
                setState(() => _obscurePass = !_obscurePass),
            child: Icon(
              _obscurePass
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: c.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ── Warning box ──────────────────────────────────────────────────────────────

  Widget _buildWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Entering the wrong Wi-Fi password is one of the most '
              'common causes of failure. Please double-check your '
              'password — it must be at least 8 characters.',
              style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connect button ───────────────────────────────────────────────────────────

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed:
            (_selectedSsid.isEmpty || _isSending) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor:
              AppColors.primary.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSending
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('Connect',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showNetworkPicker() {
    if (_isPickerOpen) return;
    _isPickerOpen = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setSheetState) {
          _sheetSetState = setSheetState;
          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Available networks',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        if (_isLoadingNetworks)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary),
                          )
                        else
                          IconButton(
                            icon: Icon(Icons.refresh,
                                color: c.textSecondary, size: 20),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _isPickerOpen = false;
                              _scanNetworks()
                                  .then((_) => _showNetworkPicker());
                            },
                          ),
                      ],
                    ),
                  ),
                  Divider(color: c.border, height: 1),
                  // Body
                  Expanded(
                    child: _buildNetworkList(ctx, scrollCtrl),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _isPickerOpen = false;
      _sheetSetState = null;
    });
  }

  Widget _buildNetworkList(
      BuildContext sheetCtx, ScrollController scrollCtrl) {
    // Show error (location off, permission denied, etc.)
    if (_scanError != null) {
      // Special case: device Location Services is OFF
      final isLocationOff =
          _scanError == 'noLocationServiceDisabled';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLocationOff ? Icons.location_off : Icons.wifi_off,
                size: 48,
                color: c.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                isLocationOff
                    ? 'Location Services is disabled'
                    : 'Cannot read Wi-Fi networks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLocationOff
                    ? 'Enable Location Services in Settings,\nthen tap ↺ to scan again.'
                    : _scanError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.5),
              ),
              const SizedBox(height: 20),
              // Open Location Settings only shown for location-off case
              if (isLocationOff)
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    _isPickerOpen = false;
                    await _openLocationSettings();
                    if (mounted) {
                      await _scanNetworks();
                      if (mounted) _showNetworkPicker();
                    }
                  },
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('Open Location Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Empty (no error, just no networks yet)
    if (_networks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off,
                  size: 48,
                  color: c.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('No networks found',
                  style: TextStyle(color: c.textSecondary)),
              const SizedBox(height: 8),
              Text(
                'Make sure Location is enabled in Settings, then tap ↺',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    // Network list
    return ListView.builder(
      controller: scrollCtrl,
      itemCount: _networks.length,
      itemBuilder: (_, i) {
        final ap = _networks[i];
        return _NetworkTile(
          ssid: ap.ssid,
          level: ap.level,
          isSelected: ap.ssid == _selectedSsid,
          onTap: () {
            setState(() => _selectedSsid = ap.ssid);
            Navigator.pop(sheetCtx);
          },
        );
      },
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    setState(() {
      _isSending = true;
      _submitError = null;
    });

    try {
      _bleDevice = BluetoothDevice.fromId(widget.device.remoteId);
      await _bleDevice!.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );

      final services = await _bleDevice!.discoverServices();
      final svc = services.firstWhere(
        (s) => s.serviceUuid.str128.toLowerCase() == _kProvSvcUuid,
        orElse: () => throw Exception('Provisioning service not found'),
      );

      BluetoothCharacteristic chr(String uuid) => svc.characteristics.firstWhere(
            (c) => c.characteristicUuid.str128.toLowerCase() == uuid,
            orElse: () => throw Exception('Missing characteristic: $uuid'),
          );
      final ssidChr   = chr(_kSsidUuid);
      final passChr   = chr(_kPassUuid);
      final statusChr = chr(_kStatusUuid);

      final completer = Completer<Map<String, dynamic>>();
      await statusChr.setNotifyValue(true);
      _notifySub = statusChr.onValueReceived.listen((bytes) {
        if (!completer.isCompleted && bytes.isNotEmpty) {
          try {
            completer.complete(
                jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
          } catch (_) {}
        }
      });

      await ssidChr.write(utf8.encode(_selectedSsid), withoutResponse: true);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await passChr.write(utf8.encode(_passCtrl.text), withoutResponse: true);

      final result =
          await completer.future.timeout(const Duration(seconds: 20));

      if (result['status'] == 'ok') {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Device reported WiFi failure');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _submitError = 'Timeout — device did not respond in 20 s');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitError = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

// ── Network tile ──────────────────────────────────────────────────────────────

class _NetworkTile extends StatelessWidget {
  final String ssid;
  final int level; // dBm
  final bool isSelected;
  final VoidCallback onTap;

  const _NetworkTile({
    required this.ssid,
    required this.level,
    required this.isSelected,
    required this.onTap,
  });

  IconData _wifiIcon() {
    if (level >= -55) return Icons.wifi;
    if (level >= -70) return Icons.wifi_2_bar;
    return Icons.wifi_1_bar;
  }

  Color _signalColor() {
    if (level >= -55) return Colors.green;
    if (level >= -70) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      leading: Icon(
        _wifiIcon(),
        color: isSelected ? AppColors.primary : _signalColor(),
      ),
      title: Text(
        ssid,
        style: TextStyle(
          color: isSelected ? AppColors.primary : c.textPrimary,
          fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        '$level dBm',
        style: TextStyle(fontSize: 11, color: c.textSecondary),
      ),
      trailing: isSelected
          ? const Icon(Icons.check,
              color: AppColors.primary, size: 18)
          : null,
      onTap: onTap,
    );
  }
}
