import 'package:material_ui/material_ui.dart';

/// Tarjeta con esquinas redondeadas y relleno consistente.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      color: color,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
