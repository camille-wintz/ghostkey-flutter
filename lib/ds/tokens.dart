// The Ghostkey design system, as the phone speaks it.
//
// A hand-mirror of the suite's token files (`_ds/tokens/*.css` — colors,
// typography, geometry, motion), kept in step by matching names: there is no
// shared package between the repos, so the contract is the names.
//
// Night only. The system defines a `day` re-fill of the same slots; this file
// is shaped so that adding it is a second object and a theme read, not a
// rewrite of every call site.

import 'package:flutter/painting.dart';

Color _hex(int rgb) => Color(0xFF000000 | rgb);

/// ── The spine ────────────────────────────────────────────────────────────
/// void→raise are the four surface steps (window → panels → rows → raised),
/// hi→faint the inks, edge/edgeHi the opaque hairlines, veil/veilHi the
/// translucent washes. `void` is LIGHTER than `panel` on purpose: panels are
/// cut into the window, not floated on it.
abstract final class Ds {
  // surfaces
  static final Color void_ = _hex(0x0a0914);
  static final Color panel = _hex(0x0c0d15);
  static final Color surf = _hex(0x11131c);
  static final Color raise = _hex(0x191c27);

  // inks
  static final Color hi = _hex(0xf2f3f9);
  static final Color ink = _hex(0xcac2cd);
  static final Color soft = _hex(0xc4c8d8);
  static final Color mid = _hex(0x9a9db1);
  static final Color low = _hex(0x7f8396);
  static final Color faint = _hex(0x47495a);

  // hairlines and washes
  static final Color edge = _hex(0x242936);
  static final Color edgeHi = _hex(0x333a4b);
  static const Color veil = Color.fromRGBO(206, 220, 255, 0.05);
  static const Color veilHi = Color.fromRGBO(206, 220, 255, 0.10);

  // The accent: one cornflower, everywhere.
  static final Color accent = _hex(0x7aa2ff);
  static final Color accent200 = _hex(0xc6d6ff);
  static final Color accent300 = _hex(0xa8c0ff);
  static final Color accent400 = _hex(0x8fb0ff);
  static final Color accent600 = _hex(0x5a83e6);

  // Meaning hues. Hue means STATE, never category.
  static final Color attention = _hex(0xd9a441);
  static final Color attention300 = _hex(0xedc888);
  static final Color attention400 = _hex(0xe2b45e);
  static final Color destructive = _hex(0xd4536a);
  static final Color done = _hex(0x45ad8a);

  /// The plan ladder — what a chapter owes. Fixed across the suite so the
  /// same colour means the same thing in every room. `write` is deliberately
  /// NOT the accent.
  static final Color planWrite = _hex(0x4bc2e0);
  static final Color planRewrite = _hex(0xd9a441);
  static final Color planLine = _hex(0xb98cff);

  /// The accent blended with the window behind it — the system's
  /// `color-mix(in srgb, var(--accent) N%, transparent)`.
  static Color accentMix(int percent) =>
      Color.fromRGBO(122, 162, 255, percent / 100);

  /// `accentMix` for the attention hue — the amber wash a notice sits in.
  static Color attentionMix(int percent) =>
      Color.fromRGBO(217, 164, 65, percent / 100);
}

/// ── Type ─────────────────────────────────────────────────────────────────
/// Two faces in the app and one the app never speaks in. Newsreader is the
/// serif voice (titles, quiet emphasis); Manrope is the app's own words. They
/// are never mixed inside one line. Spectral belongs to the writing surface
/// alone — `manuscript` is the editor's page and nothing else.
abstract final class DsFonts {
  static const String ui = 'Manrope';
  static const String prose = 'Newsreader';
  static const String manuscript = 'Spectral';
  static const String mono = 'JetBrainsMono';
}

/// One step of the ramp: a size and its paired line height, absolute.
class DsStep {
  const DsStep(this.size, this.lineHeight);
  final double size;
  final double lineHeight;

  /// Flutter's `height` is a multiplier; the system's line height is absolute.
  double get height => lineHeight / size;
}

/// One ramp, six steps.
abstract final class DsText {
  static const DsStep display = DsStep(40, 44);
  static const DsStep title = DsStep(26, 32);
  static const DsStep prose = DsStep(19, 30);
  static const DsStep body = DsStep(15, 22);
  static const DsStep ui = DsStep(13, 18);
  static const DsStep eyebrow = DsStep(11, 14);
}

/// Tracking is a ratio of the font size in CSS (`em`); resolved here against
/// the step it is used at, as absolute logical pixels.
abstract final class DsTracking {
  static const double eyebrow = 11 * 0.18;
  static const double control = 13 * 0.08;
  static const double pill = 9 * 0.1;
}

/// ── Control geometry — never varies ──────────────────────────────────────
/// One corner for everything. There is no lift token: the house is matte,
/// surfaces are separated by a hairline, never by a shadow.
abstract final class DsGeom {
  static const double radius = 16;
  static const double radiusRound = 9999;
  static const double row = 44;
  static const double ctl = 34;
  static const double panelPad = 24;
}

/// Almost everything is a 140ms fade. A screen that slides in arrives on a
/// long ease-out tail.
abstract final class DsMotion {
  static const Duration duration = Duration(milliseconds: 140);
  static const Duration screenIn = Duration(milliseconds: 190);
}

/// The app's text styles, built from the ramp. Every label reads one of these
/// rather than spelling a size; a size typed at a call site is the tell that
/// something has left the system.
abstract final class DsStyle {
  static TextStyle ui(DsStep step,
          {Color? color, FontWeight weight = FontWeight.w400, double? tracking}) =>
      TextStyle(
        fontFamily: DsFonts.ui,
        fontSize: step.size,
        height: step.height,
        fontWeight: weight,
        color: color ?? Ds.soft,
        letterSpacing: tracking,
        leadingDistribution: TextLeadingDistribution.even,
      );

  static TextStyle prose(DsStep step,
          {Color? color, FontWeight weight = FontWeight.w400}) =>
      TextStyle(
        fontFamily: DsFonts.prose,
        fontSize: step.size,
        height: step.height,
        fontWeight: weight,
        color: color ?? Ds.hi,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// The uppercase eyebrow, in the system's tracking.
  static TextStyle eyebrow({Color? color, FontWeight weight = FontWeight.w400}) =>
      ui(DsText.eyebrow, color: color ?? Ds.low, weight: weight, tracking: DsTracking.eyebrow);
}
