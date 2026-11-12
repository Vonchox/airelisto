import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace en el navegador externo. Si no es posible, avisa al usuario.
Future<void> openExternalLink(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      SnackBar(content: Text('No se pudo abrir el enlace: $url')),
    );
  }
}
