class OtaVersionInfo {
  const OtaVersionInfo({
    required this.version,
    required this.filename,
    required this.url,
  });

  final String version;
  final String filename;
  final String url;
}

class DeviceOtaCatalog {
  const DeviceOtaCatalog({
    required this.deviceId,
    required this.currentVersion,
    required this.deviceOnline,
    required this.versions,
  });

  final String deviceId;
  final String? currentVersion;
  final bool deviceOnline;
  final List<OtaVersionInfo> versions;
}
