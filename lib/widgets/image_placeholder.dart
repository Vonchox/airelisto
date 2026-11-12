import 'package:material_ui/material_ui.dart';

import '../core/constants/app_colors.dart';

/// Espacio reservado para una imagen que se incorporará más adelante.
///
/// Si [assetPath] existe en `assets/`, se muestra la imagen. Si no existe (o es
/// `null`), se muestra un marcador de posición sin provocar errores.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({
    super.key,
    this.assetPath,
    this.height = 140,
    this.icon = Icons.image_outlined,
    this.label,
    this.borderRadius = 16,
  });

  final String? assetPath;
  final double height;
  final IconData icon;
  final String? label;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: assetPath == null
            ? _placeholder()
            : Image.asset(
                assetPath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.mint,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.forestSecondary),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(
              label!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Imagen de fondo opcional: si el archivo no existe no muestra nada.
class OptionalBackdropImage extends StatelessWidget {
  const OptionalBackdropImage({super.key, required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}
