import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/inventory_controller.dart';
import '../application/settings_controller.dart';
import '../application/software_controller.dart';
import 'onboarding/onboarding_overlay.dart';
import 'sections.dart';
import 'tabs/hardware_tabs.dart';
import 'tabs/settings_tab.dart';
import 'tabs/software_tab.dart';
import 'tabs/temperatures_tab.dart';
import 'theme/glass_theme.dart';
import 'widgets/common.dart';
import 'widgets/glass.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.settings,
    required this.software,
    this.nativeVersion = '',
  });

  final InventoryController controller;
  final SettingsController settings;
  final SoftwareController software;
  final String nativeVersion;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  AppSection _section = AppSection.system;
  late final AnimationController _transition =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);
  final Map<AppSection, GlobalKey> _navKeys = {for (final s in AppSection.values) s: GlobalKey()};
  final GlobalKey _navListKey = GlobalKey();
  final GlobalKey _liveKey = GlobalKey();
  final GlobalKey _refreshKey = GlobalKey();

  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  void _select(AppSection section) {
    if (section == _section) return;
    setState(() => _section = section);
    _transition.forward(from: 0);
  }

  List<OnboardingStep> get _steps => [
        const OnboardingStep(
          icon: Icons.waving_hand_outlined,
          title: 'Bienvenido a Machine Info',
          body: 'Te mostramos en un minuto cómo moverte por la app. '
              'Puedes usar las flechas del teclado o saltar el recorrido cuando quieras.',
        ),
        OnboardingStep(
          icon: Icons.menu_open,
          title: 'Menú de secciones',
          body: 'Desde esta barra cambias entre las secciones de hardware y software. '
              'También puedes usar Ctrl + 1 … 7.',
          targets: [_navListKey],
        ),
        OnboardingStep(
          icon: AppSection.system.icon,
          title: 'Sistema',
          body: 'Resumen del sistema operativo, nombre del equipo y tiempo encendido.',
          targets: [_navKeys[AppSection.system]!],
          section: AppSection.system,
        ),
        OnboardingStep(
          icon: AppSection.cpu.icon,
          title: 'CPU, memoria y almacenamiento',
          body: 'Modelo del procesador y su uso, consumo de RAM y el espacio libre de cada unidad.',
          targets: [_navKeys[AppSection.cpu]!, _navKeys[AppSection.memory]!, _navKeys[AppSection.storage]!],
          section: AppSection.cpu,
        ),
        OnboardingStep(
          icon: AppSection.temperatures.icon,
          title: 'Temperaturas',
          body: 'Un medidor principal, el historial en vivo y cada sensor con su mínimo y máximo de la sesión.',
          targets: [_navKeys[AppSection.temperatures]!],
          section: AppSection.temperatures,
        ),
        OnboardingStep(
          icon: AppSection.software.icon,
          title: 'Software',
          body: 'Tus programas con su logo. Haz clic en uno para ver dónde se instaló, '
              'en qué lenguaje está hecho y desinstalarlo.',
          targets: [_navKeys[AppSection.software]!],
          section: AppSection.software,
        ),
        OnboardingStep(
          icon: Icons.bolt,
          title: 'Datos en vivo',
          body: 'Activa "En vivo" para refrescar el hardware cada pocos segundos, '
              'o actualiza manualmente con este botón (Ctrl + R).',
          targets: [_liveKey, _refreshKey],
        ),
        OnboardingStep(
          icon: Icons.settings_outlined,
          title: 'Ajustes',
          body: 'Elige modo día, noche o automático, la unidad de temperatura y vuelve a ver este tutorial.',
          targets: [_navKeys[AppSection.settings]!],
          section: AppSection.settings,
        ),
        const OnboardingStep(
          icon: Icons.check_circle_outline,
          title: '¡Todo listo!',
          body: 'Ya conoces lo esencial. Disfruta explorando tu equipo.',
          finalStep: true,
        ),
      ];

  Map<ShortcutActivator, VoidCallback> get _shortcuts => {
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): widget.controller.loadAll,
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): widget.controller.loadAll,
        for (var i = 0; i < AppSection.values.length; i++)
          SingleActivator(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i), control: true): () =>
              _select(AppSection.values[i]),
      };

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([widget.controller, widget.settings]);
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final settings = widget.settings;
        final showTutorial = settings.loaded && !settings.settings.onboardingCompleted;
        final compact = MediaQuery.sizeOf(context).width < 1000;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: LiquidBackground(
            child: CallbackShortcuts(
              bindings: _shortcuts,
              child: Focus(
                autofocus: true,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Sidebar(
                            compact: compact,
                            selected: _section,
                            onSelect: _select,
                            navKeys: _navKeys,
                            navListKey: _navListKey,
                            subtitle: widget.controller.hardware.value?.os.data?.hostname ?? '',
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Header(
                                  section: _section,
                                  controller: widget.controller,
                                  liveKey: _liveKey,
                                  refreshKey: _refreshKey,
                                ),
                                const SizedBox(height: 14),
                                Expanded(
                                  child: FadeTransition(
                                    opacity: CurvedAnimation(parent: _transition, curve: Curves.easeOut),
                                    child: SlideTransition(
                                      position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(
                                        CurvedAnimation(parent: _transition, curve: Curves.easeOutCubic),
                                      ),
                                      child: IndexedStack(
                                        index: _section.index,
                                        children: _pages(),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showTutorial)
                      Positioned.fill(
                        child: OnboardingOverlay(
                          steps: _steps,
                          onSectionChange: _select,
                          onFinish: () {
                            _select(AppSection.system);
                            settings.completeOnboarding();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _pages() {
    final controller = widget.controller;
    final snapshot = controller.hardware.value;
    final unit = widget.settings.settings.temperatureUnit;
    final hardware = snapshot == null
        ? List<Widget>.generate(5, (_) => _placeholder(controller.hardware.error, controller.refreshHardware))
        : <Widget>[
            SystemTab(snapshot: snapshot),
            CpuTab(section: snapshot.cpu),
            MemoryTab(section: snapshot.memory),
            StorageTab(section: snapshot.disks),
            TemperaturesTab(
              section: snapshot.temperatures,
              controller: controller,
              unit: unit,
              collectedAt: snapshot.collectedAt,
            ),
          ];
    final softwareSection = controller.software.value;
    return [
      ...hardware,
      softwareSection == null
          ? _placeholder(controller.software.error, controller.refreshSoftware)
          : SoftwareTab(
              section: softwareSection,
              software: widget.software,
              onRefresh: controller.refreshSoftware,
              platform: snapshot?.platform ?? '',
            ),
      SettingsTab(
        settings: widget.settings,
        inventory: controller,
        nativeVersion: widget.nativeVersion,
      ),
    ];
  }

  Widget _placeholder(Object? error, VoidCallback retry) {
    if (error == null) return const Center(child: CircularProgressIndicator());
    return CenteredMessage(
      icon: Icons.error_outline,
      message: 'No se pudo cargar la información.\n$error',
      action: GlassButton(onPressed: retry, icon: Icons.refresh, label: 'Reintentar'),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compact,
    required this.selected,
    required this.onSelect,
    required this.navKeys,
    required this.navListKey,
    required this.subtitle,
  });

  final bool compact;
  final AppSection selected;
  final ValueChanged<AppSection> onSelect;
  final Map<AppSection, GlobalKey> navKeys;
  final GlobalKey navListKey;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: compact ? 84 : 240,
      child: GlassPanel(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
              child: Row(
                mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Image.asset('assets/branding/app_icon.png', width: 40, height: 40, filterQuality: FilterQuality.medium),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Machine Info', style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(color: tokens.textTertiary),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Column(
              key: navListKey,
              children: [
                for (final section in AppSection.navigation)
                  _NavItem(
                    key: navKeys[section],
                    section: section,
                    selected: section == selected,
                    compact: compact,
                    onTap: () => onSelect(section),
                  ),
              ],
            ),
            const Spacer(),
            Divider(color: tokens.track, height: 24),
            _NavItem(
              key: navKeys[AppSection.settings],
              section: AppSection.settings,
              selected: selected == AppSection.settings,
              compact: compact,
              onTap: () => onSelect(AppSection.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.section,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AppSection section;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.glass;
    final selected = widget.selected;
    final color = selected ? tokens.accent : tokens.textSecondary;
    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 0 : 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? tokens.glassFillStrong
                : (_hover ? tokens.glassFill : Colors.transparent),
            border: Border.all(color: selected ? tokens.glassEdgeLight : Colors.transparent),
            boxShadow: selected ? [BoxShadow(color: tokens.shadow, blurRadius: 14, offset: const Offset(0, 4))] : null,
          ),
          child: Row(
            mainAxisAlignment: widget.compact ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: selected ? tokens.accent : Colors.transparent,
                  boxShadow: selected
                      ? [BoxShadow(color: tokens.accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 3))]
                      : null,
                ),
                child: Icon(widget.section.icon, size: 19, color: selected ? onColor(tokens.accent) : color),
              ),
              if (!widget.compact) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.section.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? tokens.textPrimary : tokens.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return widget.compact ? Tooltip(message: widget.section.label, child: item) : item;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.section,
    required this.controller,
    required this.liveKey,
    required this.refreshKey,
  });

  final AppSection section;
  final InventoryController controller;
  final GlobalKey liveKey;
  final GlobalKey refreshKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.glass;
    final loading = controller.hardware.loading || controller.software.loading;
    final collectedAt = controller.hardware.value?.collectedAt;
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Column(
                key: ValueKey(section),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(section.label, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(section.subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          if (collectedAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Actualizado ${TimeOfDay.fromDateTime(collectedAt).format(context)}',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.textTertiary),
              ),
            ),
          KeyedSubtree(
            key: liveKey,
            child: GlassPill(
              label: controller.autoRefresh ? 'En vivo' : 'Pausado',
              icon: controller.autoRefresh ? Icons.circle : Icons.pause_circle_outline,
              color: controller.autoRefresh ? tokens.success : null,
              selected: controller.autoRefresh,
              onTap: () => controller.setAutoRefresh(!controller.autoRefresh),
            ),
          ),
          const SizedBox(width: 10),
          KeyedSubtree(
            key: refreshKey,
            child: GlassIconButton(
              icon: Icons.refresh,
              tooltip: 'Actualizar (Ctrl + R)',
              onPressed: loading ? null : controller.loadAll,
              child: loading
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: tokens.accent),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
