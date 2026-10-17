import 'package:flutter/material.dart';

/// The real pictures live in `assets/art/<name>.webp`. Every place that shows
/// one keeps its code-drawn version as a fallback, so a missing picture never
/// leaves a hole.
String artPath(String name) => 'assets/art/$name.webp';

/// Inner World pieces that have a real picture (calm + giggle).
const Set<String> kPieceArt = {
  'tree', 'lake', 'house', 'mountain', 'sun', 'moon', 'flower',
  'door', 'den', 'nest', 'cauldron', 'castle',
};

/// Picture name for a badge id ('checkin-3' -> 'badge_checkin_3').
String badgeArtName(String id) => 'badge_${id.replaceAll('-', '_')}';

/// Pulls a colour toward white so tinting a picture with it recolours the
/// light areas without turning the whole thing muddy.
Color softTint(Color c, [double towardWhite = .35]) =>
    Color.lerp(c, Colors.white, towardWhite) ?? c;

class ArtImage extends StatelessWidget {
  const ArtImage(
    this.name, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.tint,
    this.fallback,
    this.opacity = 1,
    this.semanticLabel,
  });

  final String name;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Multiplies the picture by this colour (see [softTint]).
  final Color? tint;
  final Widget? fallback;
  final double opacity;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      artPath(name),
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      semanticLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      errorBuilder: (_, _, _) => fallback ?? const SizedBox.shrink(),
    );
    if (tint != null) {
      img = ColorFiltered(colorFilter: ColorFilter.mode(tint!, BlendMode.modulate), child: img);
    }
    if (opacity < 1) img = Opacity(opacity: opacity, child: img);
    return img;
  }
}

/// A picture shown dull and faded, for things not earned yet.
class LockedArt extends StatelessWidget {
  const LockedArt(this.name, {super.key, this.size = 44, this.fallback});
  final String name;
  final double size;
  final Widget? fallback;

  static const _grey = ColorFilter.matrix(<double>[
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: .45,
        child: ColorFiltered(
          colorFilter: _grey,
          child: ArtImage(name, width: size, height: size, fallback: fallback),
        ),
      );
}

/// A friendly picture above the words, for a screen with nothing in it yet.
class EmptyArt extends StatelessWidget {
  const EmptyArt(this.name, this.text, {super.key, this.size = 150});
  final String name;
  final Widget text;
  final double size;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ArtImage(name, width: size, height: size),
        const SizedBox(height: 8),
        text,
      ]);
}
