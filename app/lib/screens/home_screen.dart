import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../design/palette.dart';
import '../design/tokens.dart';
import '../design/text_styles.dart';
import '../design/icons.dart';
import '../models/device.dart';
import '../providers/devices_provider.dart';
import '../providers/homes_provider.dart';
import '../models/home.dart';
import '../widgets/device_card.dart';
import '../widgets/atoms/empty_state.dart';
import '../widgets/shell/atmosphere_app_bar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    final devicesAsync = ref.watch(devicesProvider);
    final homesAsync = ref.watch(homesProvider);
    final devices = devicesAsync.valueOrNull ?? const <Device>[];
    final roomNames = _buildRoomNames(ref, devices);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: const AtmosphereAppBar.brand(),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AtmosphereTokens.space20,
                AtmosphereTokens.space24,
                AtmosphereTokens.space20,
                AtmosphereTokens.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Devices',
                    style: AtmosphereTextStyles.pageTitle(c.ink),
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    'Real-time environmental monitoring across your connected spaces.',
                    style: AtmosphereTextStyles.body(c.ink2),
                  ),
                ],
              ),
            ),
          ),
          devicesAsync.when(
            data: (devices) => devices.isEmpty
                ? _buildEmptyState(context, homesAsync)
                : _buildDeviceList(context, devices, roomNames),
            loading: () => _buildLoadingState(context, c),
            error: (error, stack) => _buildErrorState(context, c, error, ref),
          ),
          const SliverPadding(
            padding: EdgeInsets.only(bottom: AtmosphereTokens.space32),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddDevice(context, homesAsync),
        backgroundColor: c.mint,
        child: Icon(AppIcons.plus, color: c.brand, size: 28),
      ),
    );
  }


  Widget _buildEmptyState(
    BuildContext context,
    AsyncValue<List<Home>> homesAsync,
  ) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyState(
        icon: AppIcons.radar,
        title: 'No devices yet',
        body:
            'Add your first Smart Air device to start monitoring air quality in your home.',
        primaryAction: 'Add a device',
        onPrimaryAction: () => _handleAddDevice(context, homesAsync),
      ),
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    List<Device> devices,
    Map<String, String> roomNames,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AtmosphereTokens.space20,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final device = devices[index];
            return Padding(
              padding: const EdgeInsets.only(
                bottom: AtmosphereTokens.space16,
              ),
              child: DeviceCard(
                device: device,
                roomName:
                    device.roomId == null ? null : roomNames[device.roomId!],
                onTap: () => context.push('/devices/${device.id}'),
              ),
            );
          },
          childCount: devices.length,
        ),
      ),
    );
  }

  Map<String, String> _buildRoomNames(WidgetRef ref, List<Device> devices) {
    final roomNames = <String, String>{};
    final homeIds = devices.map((device) => device.homeId).toSet();

    for (final homeId in homeIds) {
      final rooms =
          ref.watch(roomsProvider(homeId)).valueOrNull ?? const <Room>[];
      for (final room in rooms) {
        roomNames[room.id] = room.name;
      }
    }

    return roomNames;
  }

  Widget _buildLoadingState(BuildContext context, AtmospherePalette c) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AtmosphereTokens.space20,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: AtmosphereTokens.space16,
              ),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: c.line2,
                  borderRadius: BorderRadius.circular(
                    AtmosphereTokens.radiusCard,
                  ),
                ),
              ),
            );
          },
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    AtmospherePalette c,
    Object error,
    WidgetRef ref,
  ) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: EmptyState(
        icon: AppIcons.warn,
        title: 'Failed to load devices',
        body: error.toString(),
        primaryAction: 'Retry',
        onPrimaryAction: () {
          ref.invalidate(devicesProvider);
        },
      ),
    );
  }

  void _handleAddDevice(
    BuildContext context,
    AsyncValue<List<Home>> homesAsync,
  ) {
    final homes = homesAsync.valueOrNull ?? const <Home>[];
    if (homesAsync.isLoading && homes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading homes...')),
      );
      return;
    }
    if (homes.isEmpty) {
      context.push('/homes/create');
      return;
    }
    if (homes.length == 1) {
      context.push('/provision?homeId=${Uri.encodeComponent(homes.first.id)}');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final c = sheetContext.colors;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AtmosphereTokens.space20,
                  AtmosphereTokens.space20,
                  AtmosphereTokens.space20,
                  AtmosphereTokens.space8,
                ),
                child: Text(
                  'Choose a home',
                  style: AtmosphereTextStyles.h2(c.ink),
                ),
              ),
              for (final home in homes)
                ListTile(
                  title: Text(home.name),
                  subtitle: home.address == null ? null : Text(home.address!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(
                      '/provision?homeId=${Uri.encodeComponent(home.id)}',
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
