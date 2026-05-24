import 'package:flutter_test/flutter_test.dart';
import 'package:smart_air/core/app_config.dart';

void main() {
  test('matchesProvisioningName accepts provisioning and legacy prefixes', () {
    expect(BleConfig.matchesProvisioningName('SMART_AIR_13ED8C'), isTrue);
    expect(BleConfig.matchesProvisioningName('SmartAir-13ED8C'), isTrue);
  });

  test('matchesProvisioningName rejects embedded provisioning substrings', () {
    expect(
        BleConfig.matchesProvisioningName('prefix SMART_AIR_13ED8C'), isFalse);
    expect(BleConfig.matchesProvisioningName('Device SMART_AIR_13ED8C suffix'),
        isFalse);
  });
}
