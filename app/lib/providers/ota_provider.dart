import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ota.dart';
import '../services/device_service.dart';

final otaCatalogProvider =
    FutureProvider.autoDispose.family<DeviceOtaCatalog, String>((
  ref,
  deviceId,
) {
  return ref.read(deviceServiceProvider).getOtaCatalog(deviceId);
});
