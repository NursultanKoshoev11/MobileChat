import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'ui_helpers.dart';

class KoomPageBackground extends StatelessWidget {
  const KoomPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.page,
      child: child,
    );
  }
}

class KoomLogoMark extends StatelessWidget {
  const KoomLogoMark({
    super.key,
    this.size = 72,
    this.showShadow = true,
  });

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: MobileChatTheme.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.31),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: MobileChatTheme.primary.withValues(alpha: 0.28),
                  blurRadius: size * 0.32,
                  offset: Offset(0, size * 0.14),
                ),
              ]
            : const [],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.58,
            height: size * 0.51,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: size * 0.052),
              borderRadius: BorderRadius.circular(size * 0.17),
            ),
          ),
          Positioned(
            bottom: size * 0.205,
            left: size * 0.245,
            child: Transform.rotate(
              angle: 0.55,
              child: Container(
                width: size * 0.13,
                height: size * 0.13,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  border: Border(
                    left: BorderSide(color: Colors.white, width: size * 0.048),
                    bottom:
                        BorderSide(color: Colors.white, width: size * 0.048),
                  ),
                ),
              ),
            ),
          ),
          Text(
            'K',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -size * 0.035,
            ),
          ),
        ],
      ),
    );
  }
}

class KoomBrandTitle extends StatelessWidget {
  const KoomBrandTitle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KoomLogoMark(size: compact ? 38 : 50, showShadow: false),
        SizedBox(width: compact ? 10 : 13),
        Text(
          'Koom',
          style: TextStyle(
            color: colors.textStrong,
            fontSize: compact ? 23 : 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}

class KoomCard extends StatelessWidget {
  const KoomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.radius = 24,
    this.gradient,
    this.borderColor,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final double radius;
  final Gradient? gradient;
  final Color? borderColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final decoration = BoxDecoration(
      color: gradient == null ? colors.surface : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (gradient == null
                ? colors.border
                : Colors.white.withValues(alpha: 0.16)),
      ),
      boxShadow: showShadow
          ? [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ]
          : const [],
    );
    final content = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: decoration,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}


class KoomResponsiveActions extends StatelessWidget {
  const KoomResponsiveActions({
    super.key,
    required this.children,
    this.breakpoint = 430,
    this.spacing = 10,
  });

  final List<Widget> children;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaledBodySize = MediaQuery.textScalerOf(context).scale(14);
        final stackVertically =
            constraints.maxWidth < breakpoint || scaledBodySize > 17.5;

        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                SizedBox(width: double.infinity, child: children[index]),
                if (index < children.length - 1) SizedBox(height: spacing),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1) SizedBox(width: spacing),
            ],
          ],
        );
      },
    );
  }
}

class KoomAdaptiveTileGrid extends StatelessWidget {
  const KoomAdaptiveTileGrid({
    super.key,
    required this.children,
    this.minItemWidth = 112,
    this.maxColumns = 4,
    this.spacing = 8,
    this.runSpacing = 8,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final calculatedColumns =
            ((availableWidth + spacing) / (minItemWidth + spacing)).floor();
        final columns = calculatedColumns.clamp(1, maxColumns).toInt();
        final itemWidth =
            (availableWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class KoomAdaptiveFab extends StatelessWidget {
  const KoomAdaptiveFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.compactBreakpoint = 380,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < compactBreakpoint ||
        MediaQuery.textScalerOf(context).scale(14) > 17.5;

    if (compact) {
      return FloatingActionButton(
        onPressed: onPressed,
        tooltip: label,
        child: Icon(icon),
      );
    }

    return FloatingActionButton.extended(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class KoomIconTile extends StatelessWidget {
  const KoomIconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 88 : 102),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 10,
              vertical: compact ? 8 : 10,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: compact ? 42 : 48,
                      height: compact ? 42 : 48,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(icon,
                          color: scheme.primary, size: compact ? 21 : 24),
                    ),
                    if ((badge ?? 0) > 0)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Badge(label: Text('${badge!}')),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class KoomAvatar extends StatelessWidget {
  const KoomAvatar({
    super.key,
    required this.label,
    this.radius = 24,
    this.icon,
    this.background,
    this.imageBytes,
  });

  final String label;
  final double radius;
  final IconData? icon;
  final Color? background;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        gradient: background == null ? MobileChatTheme.brandGradient : null,
        color: background,
        borderRadius: BorderRadius.circular(radius * 0.72),
        boxShadow: [
          BoxShadow(
            color: MobileChatTheme.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: imageBytes != null && imageBytes!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius * 0.72),
              child: Image.memory(
                imageBytes!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            )
          : icon != null
              ? Icon(icon, color: Colors.white, size: radius)
              : Text(
                  avatarText(label),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.82,
                    fontWeight: FontWeight.w900,
                  ),
                ),
    );
  }
}

class KoomStatusPill extends StatelessWidget {
  const KoomStatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.primary;
    final maxWidth =
        (MediaQuery.sizeOf(context).width - 48).clamp(120.0, 420.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: effective.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: effective.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: effective),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: effective,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KoomSectionTitle extends StatelessWidget {
  const KoomSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    if (trailing == null) return titleBlock;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 17.5;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 12),
            trailing!,
          ],
        );
      },
    );
  }
}

class KoomEmptyState extends StatelessWidget {
  const KoomEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 54),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              icon,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, height: 1.45),
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(width: double.infinity, child: action!),
            ),
          ],
        ],
      ),
    );
  }
}

class KoomSheetFrame extends StatelessWidget {
  const KoomSheetFrame({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.showClose = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: screenHeight * 0.92,
            ),
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: colors.textMuted.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  if (title != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title!,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (subtitle != null && subtitle!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    color: colors.textMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showClose) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ],
                    ),
                  if (title != null) const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
