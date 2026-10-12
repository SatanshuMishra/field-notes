import 'package:url_launcher/url_launcher.dart';

typedef LinkOpener = Future<bool> Function(Uri link);

Future<bool> openInBrowser(Uri link) =>
    launchUrl(link, mode: LaunchMode.externalApplication);
