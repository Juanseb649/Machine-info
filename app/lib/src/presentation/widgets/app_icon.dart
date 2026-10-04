import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../application/software_controller.dart';
import '../../domain/entities.dart';

const _monogramPalettes = [
  [Color(0xFF5AC8FA), Color(0xFF0A84FF)],
  [Color(0xFFBF5AF2), Color(0xFF5E5CE6)],
  [Color(0xFFFF9F0A), Color(0xFFFF375F)],
  [Color(0xFF30D158), Color(0xFF00A3A3)],
  [Color(0xFFFF6482), Color(0xFFBF5AF2)],
  [Color(0xFF64D2FF), Color(0xFF30B0C7)],
  [Color(0xFFFFD60A), Color(0xFFFF9F0A)],
  [Color(0xFF8E8E93), Color(0xFF48484A)],
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
