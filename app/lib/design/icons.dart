import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Semantic icon registry for Atmosphere design system.
/// Wraps Lucide icons so callers never reference the package directly.
/// Source: tmp/app/screens-chrome.jsx:46-91
class AppIcons {
  AppIcons._();

  // Status bar / chrome
  static const IconData wifi      = LucideIcons.wifi;
  static const IconData bluetooth = LucideIcons.bluetooth;
  static const IconData signal    = LucideIcons.signal;
  static const IconData battery   = LucideIcons.battery;

  // Nav
  static const IconData home          = LucideIcons.home;
  static const IconData notifications = LucideIcons.bell;
  static const IconData profile       = LucideIcons.user;

  // Device
  static const IconData device     = LucideIcons.radio;
  static const IconData wind       = LucideIcons.wind;
  static const IconData bulb       = LucideIcons.lightbulb;
  static const IconData fan        = LucideIcons.fan;
  static const IconData smog       = LucideIcons.cloudFog;
  static const IconData cloud      = LucideIcons.cloud;
  static const IconData temp       = LucideIcons.thermometer;
  static const IconData humidity   = LucideIcons.droplet;

  // Action
  static const IconData plus       = LucideIcons.plus;
  static const IconData more       = LucideIcons.moreHorizontal;
  static const IconData back       = LucideIcons.arrowLeft;
  static const IconData refresh    = LucideIcons.refreshCw;
  static const IconData edit       = LucideIcons.pencil;
  static const IconData trash      = LucideIcons.trash2;
  static const IconData cog        = LucideIcons.settings;
  static const IconData check      = LucideIcons.check;
  static const IconData close      = LucideIcons.x;
  static const IconData info       = LucideIcons.info;
  static const IconData warn       = LucideIcons.alertTriangle;
  static const IconData chev       = LucideIcons.chevronRight;
  static const IconData chevDown   = LucideIcons.chevronDown;
  static const IconData lock       = LucideIcons.lock;
  static const IconData eye        = LucideIcons.eye;
  static const IconData eyeOff     = LucideIcons.eyeOff;
  static const IconData pin        = LucideIcons.mapPin;
  static const IconData chart      = LucideIcons.lineChart;
  static const IconData bolt       = LucideIcons.zap;
  static const IconData radar      = LucideIcons.radar;
  static const IconData download   = LucideIcons.download;
  static const IconData qr         = LucideIcons.qrCode;
  // Auth = email + password only. No SSO icons (Google/Apple intentionally omitted).
}
