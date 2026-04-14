import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/ble_models.dart';
import '../widgets/device_card.dart';
import 'ble_scan_screen.dart';
import 'wifi_setup_screen.dart';

class _DeviceInfo {
  final String id;
  final String name;
  final String room;
  final bool isOnline;
  final bool isProvisioned; // true once WiFi credentials have been sent
  final String? temperature;
  final String? humidity;

  const _DeviceInfo({
    required this.id,
    required this.name,
    required this.room,
    this.isOnline = false,
    this.isProvisioned = false,
    this.temperature,
    this.humidity,
  });

  _DeviceInfo copyWith({
    bool? isProvisioned,
    bool? isOnline,
    String? temperature,
    String? humidity,
  }) =>
      _DeviceInfo(
        id: id,
        name: name,
        room: room,
        isOnline: isOnline ?? this.isOnline,
        isProvisioned: isProvisioned ?? this.isProvisioned,
        temperature: temperature ?? this.temperature,
        humidity: humidity ?? this.humidity,
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _roomIndex = 0;
  String _homeName = 'Smart Home';

  final _rooms = ['All', 'Living room', 'Bedroom'];

  final _devices = <_DeviceInfo>[];

  AppPalette get c => context.colors;

  List<_DeviceInfo> get _filteredDevices {
    if (_roomIndex == 0) return _devices;
    return _devices.where((d) => d.room == _rooms[_roomIndex]).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildRoomTabs()),
          _buildGrid(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: c.bg,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // App logo
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.home, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          // App / home name (tappable to rename)
          GestureDetector(
            onTap: _renameHome,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _homeName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: c.textSecondary, size: 22),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none, color: c.textPrimary, size: 24),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: Icon(Icons.add, color: c.textPrimary, size: 24),
          onPressed: () {
            _showAddDevice(context);
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Room tabs ─────────────────────────────────────────────────────────────
  Widget _buildRoomTabs() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // +1 for the "+" add-room button at the end
        itemCount: _rooms.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          // Last item — add room button
          if (i == _rooms.length) {
            return InkWell(
              onTap: _addRoom,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.add, color: c.textSecondary, size: 18),
              ),
            );
          }

          final selected = i == _roomIndex;
          return InkWell(
            onTap: () => setState(() => _roomIndex = i),
            // Long press on any tab except "all rooms" (index 0)
            onLongPress: i == 0 ? null : () => _showRoomOptions(i),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2.5,
                    color: selected ? AppColors.primary : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                _rooms[i],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? c.textPrimary : c.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Device grid ───────────────────────────────────────────────────────────
  Widget _buildGrid() {
    final items = _filteredDevices;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        delegate: SliverChildListDelegate([
          ...items.map(
            (d) => GestureDetector(
              onLongPress: () => _confirmDeleteDevice(d),
              onTap: () => _openDevice(d),
              child: DeviceCard(
                name: d.name,
                room: d.room,
                isOnline: d.isOnline,
                isProvisioned: d.isProvisioned,
                temperature: d.temperature,
                humidity: d.humidity,
              ),
            ),
          ),
          _AddDeviceCard(onTap: () {
            _showAddDevice(context);
          }),
        ]),
      ),
    );
  }

  /// Tap device — if not provisioned, show WiFi setup.
  Future<void> _openDevice(_DeviceInfo device) async {
    if (device.isProvisioned) {
      // TODO: navigate to device detail / sensor dashboard
      return;
    }
    // Not yet provisioned — open WiFi setup screen.
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WifiSetupScreen(
          device: BleDeviceInfo(
            remoteId: device.id.replaceFirst('ble-', ''),
            name: device.name,
            rssi: -60,
          ),
        ),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        final idx = _devices.indexWhere((d) => d.id == device.id);
        if (idx != -1) {
          _devices[idx] = _devices[idx].copyWith(isProvisioned: true);
        }
      });
    }
  }

  Future<void> _showAddDevice(BuildContext context) async {
    final result = await Navigator.of(context).push<BleConnectResult>(
      MaterialPageRoute(builder: (_) => const BleDeviceScanScreen()),
    );

    if (result == null || !mounted) return;

    setState(() {
      final room = _roomIndex == 0
          ? (_rooms.length > 1 ? _rooms[1] : 'Living room')
          : _rooms[_roomIndex];
      _devices.add(_DeviceInfo(
        id: 'ble-${result.device.remoteId}',
        name: result.device.name,
        room: room,
        isOnline: true,
        isProvisioned: result.isProvisioned,
        temperature: result.snapshot?.temperatureLabel,
        humidity: result.snapshot?.humidityLabel,
      ));
    });
  }

  // ── Delete device (long press) ────────────────────────────────────────────
  void _confirmDeleteDevice(_DeviceInfo device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  device.name,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove device',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(
                      () => _devices.removeWhere((d) => d.id == device.id));
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: c.textSecondary),
                title: Text('Cancel', style: TextStyle(color: c.textSecondary)),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Room options (long press on tab) ──────────────────────────────────────
  void _showRoomOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  _rooms[index],
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: c.textSecondary),
                title: Text('Rename room',
                    style: TextStyle(color: c.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameRoom(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove room',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _rooms.removeAt(index);
                    if (_roomIndex == index || _roomIndex >= _rooms.length) {
                      _roomIndex = 0;
                    }
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.close, color: c.textSecondary),
                title: Text('Cancel', style: TextStyle(color: c.textSecondary)),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _renameRoom(int index) {
    final ctrl = TextEditingController(text: _rooms[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Rename room', style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
            focusedBorder: UnderlineInputBorder(
                borderSide: const BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  final old = _rooms[index];
                  _rooms[index] = name;
                  // keep devices in sync with the renamed room
                  for (var i = 0; i < _devices.length; i++) {
                    if (_devices[i].room == old) {
                      _devices[i] = _DeviceInfo(
                        id: _devices[i].id,
                        name: _devices[i].name,
                        room: name,
                        isOnline: _devices[i].isOnline,
                        temperature: _devices[i].temperature,
                        humidity: _devices[i].humidity,
                      );
                    }
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child:
                const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _addRoom() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Add room', style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Room name',
            hintStyle: TextStyle(color: c.textSecondary),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _rooms.add(name);
                  _roomIndex = _rooms.length - 1;
                });
              }
              Navigator.pop(ctx);
            },
            child:
                const Text('Add', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _renameHome() {
    final ctrl = TextEditingController(text: _homeName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Rename home', style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Home name',
            hintStyle: TextStyle(color: c.textSecondary),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) setState(() => _homeName = name);
              Navigator.pop(ctx);
            },
            child:
                const Text('Save', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ── Add device placeholder card ───────────────────────────────────────────────
class _AddDeviceCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDeviceCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.surfaceVar,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.add, color: c.textSecondary, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              'Add device',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
