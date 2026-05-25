import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/back_navigation.dart';
import '../../design/icons.dart';
import '../../design/palette.dart';
import '../../design/text_styles.dart';
import '../../design/tokens.dart';
import '../../models/home.dart';
import '../../providers/auth_provider.dart';
import '../../providers/homes_provider.dart';
import '../../widgets/atoms/danger_button.dart';
import '../../widgets/atoms/empty_state.dart';
import '../../widgets/shell/atmosphere_app_bar.dart';

class HomeDetailScreen extends ConsumerStatefulWidget {
  const HomeDetailScreen({
    super.key,
    required this.homeId,
    this.fallbackRoute = '/homes',
  });
  final String homeId;
  final String fallbackRoute;

  @override
  ConsumerState<HomeDetailScreen> createState() => _HomeDetailScreenState();
}

class _HomeDetailScreenState extends ConsumerState<HomeDetailScreen> {
  final _nameController = TextEditingController();
  bool _editingName = false;
  bool _savingName = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Home? _findHome(List<Home> homes) {
    for (final home in homes) {
      if (home.id == widget.homeId) return home;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final homesState = ref.watch(homesProvider);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.valueOrNull?.id;
    final roomsState = ref.watch(roomsProvider(widget.homeId));

    final homes = homesState.valueOrNull ?? const <Home>[];
    final home = _findHome(homes);

    if (homesState.isLoading && home == null) {
      return BackNavigationScope(
        fallbackRoute: widget.fallbackRoute,
        child: Scaffold(
          backgroundColor: c.bg,
          appBar: AtmosphereAppBar.back(
            title: 'Home',
            onBack: () => handleBackOrFallback(context, widget.fallbackRoute),
          ),
          body: Center(child: CircularProgressIndicator(color: c.brand)),
        ),
      );
    }

    if (home == null) {
      return BackNavigationScope(
        fallbackRoute: widget.fallbackRoute,
        child: Scaffold(
          backgroundColor: c.bg,
          appBar: AtmosphereAppBar.back(
            title: 'Home',
            onBack: () => handleBackOrFallback(context, widget.fallbackRoute),
          ),
          body: EmptyState(
            icon: AppIcons.home,
            title: 'Home not found',
            body: homesState.hasError
                ? homesState.error.toString()
                : 'This home is no longer available in your current session.',
            secondaryAction: 'Back',
            onSecondaryAction: () =>
                handleBackOrFallback(context, widget.fallbackRoute),
          ),
        ),
      );
    }

    final isOwner = home.ownerId == currentUserId;

    return BackNavigationScope(
      fallbackRoute: widget.fallbackRoute,
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AtmosphereAppBar.back(
          title: home.name,
          onBack: () => handleBackOrFallback(context, widget.fallbackRoute),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AtmosphereTokens.space16),
          children: [
            Text(
              'HOME NAME',
              style: AtmosphereTextStyles.label(c.ink3),
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            Container(
              padding: const EdgeInsets.all(AtmosphereTokens.space16),
              decoration: BoxDecoration(
                color: c.paper,
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusCard),
                border: Border.all(color: c.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _editingName
                        ? TextField(
                            controller: _nameController,
                            autofocus: true,
                            style: AtmosphereTextStyles.body(c.ink),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Home name',
                              hintStyle: AtmosphereTextStyles.body(c.ink3),
                            ),
                          )
                        : Text(
                            home.name,
                            style: AtmosphereTextStyles.body(c.ink),
                          ),
                  ),
                  if (isOwner)
                    IconButton(
                      icon: Icon(
                        _editingName ? AppIcons.check : AppIcons.edit,
                        size: 20,
                        color: c.brand,
                      ),
                      onPressed: _savingName
                          ? null
                          : () {
                              if (_editingName) {
                                _saveName();
                              } else {
                                setState(() {
                                  _editingName = true;
                                  _nameController.text = home.name;
                                });
                              }
                            },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MEMBERS',
                    style: AtmosphereTextStyles.label(c.ink3),
                  ),
                ),
                if (isOwner)
                  TextButton.icon(
                    onPressed: _showInviteMember,
                    icon: Icon(AppIcons.plus, size: 16, color: c.brand),
                    label: Text(
                      'Invite',
                      style: AtmosphereTextStyles.caption(c.brand),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            Container(
              padding: const EdgeInsets.all(AtmosphereTokens.space16),
              decoration: BoxDecoration(
                color: c.paper,
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusCard),
                border: Border.all(color: c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MemberRow(
                    name: authState.valueOrNull?.email ?? 'Current user',
                    role: isOwner ? 'Owner' : 'Member',
                    isYou: true,
                  ),
                  const SizedBox(height: AtmosphereTokens.space8),
                  Text(
                    'The current API exposes invite actions, but it does not return a full member list yet.',
                    style: AtmosphereTextStyles.caption(c.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ROOMS',
                    style: AtmosphereTextStyles.label(c.ink3),
                  ),
                ),
                if (isOwner)
                  TextButton.icon(
                    onPressed: _showAddRoom,
                    icon: Icon(AppIcons.plus, size: 16, color: c.brand),
                    label: Text(
                      'Add',
                      style: AtmosphereTextStyles.caption(c.brand),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            roomsState.when(
              data: (rooms) => Container(
                decoration: BoxDecoration(
                  color: c.paper,
                  borderRadius:
                      BorderRadius.circular(AtmosphereTokens.radiusCard),
                  border: Border.all(color: c.line),
                ),
                child: rooms.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AtmosphereTokens.space16),
                        child: Text(
                          'No rooms yet',
                          style: AtmosphereTextStyles.caption(c.ink3),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < rooms.length; i++) ...[
                            if (i > 0) Divider(height: 1, color: c.line),
                            _RoomRow(
                              name: rooms[i].name,
                              canManage: isOwner,
                              onEdit: () =>
                                  _showEditRoom(rooms[i].id, rooms[i].name),
                              onDelete: () => _confirmDeleteRoom(rooms[i].id),
                            ),
                          ],
                        ],
                      ),
              ),
              loading: () => Container(
                padding: const EdgeInsets.all(AtmosphereTokens.space16),
                decoration: BoxDecoration(
                  color: c.paper,
                  borderRadius:
                      BorderRadius.circular(AtmosphereTokens.radiusCard),
                  border: Border.all(color: c.line),
                ),
                child: Center(
                  child: CircularProgressIndicator(color: c.brand),
                ),
              ),
              error: (error, _) => Container(
                padding: const EdgeInsets.all(AtmosphereTokens.space16),
                decoration: BoxDecoration(
                  color: c.paper,
                  borderRadius:
                      BorderRadius.circular(AtmosphereTokens.radiusCard),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  error.toString(),
                  style: AtmosphereTextStyles.caption(c.danger),
                ),
              ),
            ),
            const SizedBox(height: AtmosphereTokens.space32),
            Text(
              'DANGER ZONE',
              style: AtmosphereTextStyles.label(c.danger),
            ),
            const SizedBox(height: AtmosphereTokens.space12),
            if (isOwner) ...[
              DangerButton(
                label: 'Delete home',
                onPressed: _confirmDeleteHome,
              ),
              const SizedBox(height: AtmosphereTokens.space8),
              Text(
                'This deletes the home, every device in it, and their associated data.',
                style: AtmosphereTextStyles.caption(c.danger),
                textAlign: TextAlign.center,
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(AtmosphereTokens.space16),
                decoration: BoxDecoration(
                  color: c.paper,
                  borderRadius:
                      BorderRadius.circular(AtmosphereTokens.radiusCard),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  'Leaving a home is not exposed by the current API yet.',
                  style: AtmosphereTextStyles.caption(c.ink3),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AtmosphereTokens.space32),
          ],
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a home name.');
      return;
    }

    setState(() => _savingName = true);
    try {
      await ref.read(homesProvider.notifier).updateName(widget.homeId, name);
      if (!mounted) return;
      setState(() {
        _editingName = false;
      });
      _showSnack('Home name updated.');
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _savingName = false);
      }
    }
  }

  Future<void> _showInviteMember() async {
    final email = await _promptForText(
      title: 'Invite member',
      label: 'Email address',
      initialValue: '',
    );
    if (email == null) return;

    try {
      await ref.read(homesProvider.notifier).inviteMember(widget.homeId, email);
      _showSnack('Invitation sent if the account exists.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _showAddRoom() async {
    final name = await _promptForText(
      title: 'Add room',
      label: 'Room name',
      initialValue: '',
    );
    if (name == null) return;

    try {
      await ref.read(roomsProvider(widget.homeId).notifier).create(name);
      _showSnack('Room created.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _showEditRoom(String roomId, String currentName) async {
    final name = await _promptForText(
      title: 'Edit room',
      label: 'Room name',
      initialValue: currentName,
    );
    if (name == null) return;

    try {
      await ref
          .read(roomsProvider(widget.homeId).notifier)
          .updateRoom(roomId, name);
      _showSnack('Room updated.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _confirmDeleteRoom(String roomId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete room'),
        content: const Text(
          'Devices assigned to this room will remain in the home but lose the room assignment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(roomsProvider(widget.homeId).notifier).delete(roomId);
      _showSnack('Room deleted.');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<void> _confirmDeleteHome() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete home'),
        content: const Text(
          'This will permanently delete this home and all its devices. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AtmosphereTokens.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(homesProvider.notifier).delete(widget.homeId);
      if (!mounted) return;
      context.go('/homes');
    } catch (error) {
      _showSnack(error.toString());
    }
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    required String initialValue,
  }) async {
    var value = initialValue;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextFormField(
          initialValue: initialValue,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onChanged: (next) => value = next,
          onFieldSubmitted: (next) {
            final trimmed = next.trim();
            Navigator.pop(ctx, trimmed.isEmpty ? null : trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = value.trim();
              Navigator.pop(ctx, trimmed.isEmpty ? null : trimmed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.role,
    this.isYou = false,
  });

  final String name;
  final String role;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.brandTint,
          ),
          child: Center(
            child: Text(
              name[0].toUpperCase(),
              style: AtmosphereTextStyles.body(c.brand),
            ),
          ),
        ),
        const SizedBox(width: AtmosphereTokens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AtmosphereTextStyles.body(c.ink),
              ),
              Text(
                role,
                style: AtmosphereTextStyles.caption(c.ink3),
              ),
            ],
          ),
        ),
        if (isYou)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AtmosphereTokens.space8,
              vertical: AtmosphereTokens.space4,
            ),
            decoration: BoxDecoration(
              color: c.brandTint,
              borderRadius: BorderRadius.circular(AtmosphereTokens.radiusPill),
            ),
            child: Text(
              'You',
              style: AtmosphereTextStyles.pill(c.brand),
            ),
          ),
      ],
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.name,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AtmosphereTokens.space16,
        vertical: AtmosphereTokens.space12,
      ),
      child: Row(
        children: [
          Icon(AppIcons.home, size: 20, color: c.ink2),
          const SizedBox(width: AtmosphereTokens.space12),
          Expanded(
            child: Text(
              name,
              style: AtmosphereTextStyles.body(c.ink),
            ),
          ),
          if (canManage) ...[
            IconButton(
              icon: Icon(AppIcons.edit, size: 16, color: c.ink3),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(AppIcons.trash, size: 16, color: c.danger),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
