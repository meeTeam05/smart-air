import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/home.dart';
import '../services/home_service.dart';

final homesProvider =
    AsyncNotifierProvider<HomesNotifier, List<Home>>(HomesNotifier.new);

class HomesNotifier extends AsyncNotifier<List<Home>> {
  late HomeService _service;

  @override
  Future<List<Home>> build() async {
    _service = ref.read(homeServiceProvider);
    return _service.getHomes();
  }

  Future<void> create(String name, {String? timezone}) async {
    final home = await _service.createHome(name, timezone: timezone);
    state = AsyncData([...state.valueOrNull ?? [], home]);
  }

  Future<void> delete(String id) async {
    await _service.deleteHome(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((h) => h.id != id).toList(),
    );
  }

  Future<void> inviteMember(String homeId, String email,
      {String role = 'member'}) async {
    await _service.inviteMember(homeId, email, role: role);
  }
}

final roomsProvider = AsyncNotifierProviderFamily<RoomsNotifier, List<Room>, String>(
    RoomsNotifier.new);

class RoomsNotifier extends FamilyAsyncNotifier<List<Room>, String> {
  late HomeService _service;

  @override
  Future<List<Room>> build(String homeId) async {
    _service = ref.read(homeServiceProvider);
    return _service.getRooms(homeId);
  }

  Future<void> create(String name) async {
    final room = await _service.createRoom(arg, name);
    state = AsyncData([...state.valueOrNull ?? [], room]);
  }
}
