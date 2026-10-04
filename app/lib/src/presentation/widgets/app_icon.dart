import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../application/software_controller.dart';
import '../../domain/entities.dart';

const _monogramPalettes = [
  [Color(0xFF3A9D90), Color(0xFF23766C)],
  [Color(0xFFEDB458), Color(0xFFC9861F)],
  [Color(0xFFE2735F), Color(0xFFB84A37)],
  [Color(0xFF55534C), Color(0xFF22211E)],
  [Color(0xFF8EDACF), Color(0xFF2E8C80)],
  [Color(0xFFF4A797), Color(0xFFD45B47)],
  [Color(0xFFF8D894), Color(0xFFE3A23B)],
  [Color(0xFF7DB6CC), Color(0xFF4A7F96)],
];

class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.package, required this.software, this.size = 48});

  final InstalledPackage package;
  final SoftwareController software;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = software.isIconResolved(package);
    return SizedBox.square(
      dimension: size,
      child: resolved
          ? _frame(software.resolvedIcon(package))
          : FutureBuilder<Uint8List?>(
              future: software.icon(package),
              builder: (context, snapshot) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(snapshot.connectionState == ConnectionState.done),
                  child: _frame(snapshot.data),
                ),
              ),
            ),
    );
  }

  Widget _frame(Uint8List? bytes) {
    final radius = BorderRadius.circular(size * 0.26);
    if (bytes != null && bytes.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.all(size * 0.04),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _Monogram(name: package.name, size: size, radius: radius),
        ),
      );
    }
    return _Monogram(name: package.name, size: size, radius: radius);
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.size, required this.radius});

  final String name;
  final double size;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    final palette = _monogramPalettes[trimmed.toLowerCase().hashCode.abs() % _monogramPalettes.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: palette),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: palette.last.withValues(alpha: 0.30), blurRadius: size * 0.25, offset: Offset(0, size * 0.06))],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(color: Colors.white, fontSize: size * 0.44, fontWeight: FontWeight.w700),
      ),
    );
  }
}
