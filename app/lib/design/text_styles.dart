import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AtmosphereTextStyles {
  AtmosphereTextStyles._();

  static TextStyle pageTitle(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.9, color: color,
  );
  static TextStyle h1(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: color,
  );
  static TextStyle h2(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: color,
  );
  static TextStyle sensorValue(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.75, color: color,
  );
  static TextStyle label(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.4, color: color,
  );
  static TextStyle body(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 15, fontWeight: FontWeight.w500, color: color,
  );
  static TextStyle caption(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 13, fontWeight: FontWeight.w400, color: color,
  );
  static TextStyle pill(Color color) => GoogleFonts.plusJakartaSans(
    fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: color,
  );
  static TextStyle mono(Color color, {double size = 13}) => GoogleFonts.jetBrainsMono(
    fontSize: size, fontWeight: FontWeight.w400, color: color,
  );
}
