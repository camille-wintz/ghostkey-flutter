import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where an author changes what they pay: the website, not a checkout in the
/// app. A purchase flow that is not Play Billing is what gets a build
/// rejected, so the app reports the plan and never sells it.
const String webAccountUrl = 'https://ghost-key.app/';

/// Open the web app in the browser, or say where to go when no browser will.
Future<void> openWebAccount(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(webAccountUrl), mode: LaunchMode.externalApplication)
      .catchError((_) => false);
  if (ok || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Could not open the browser'),
      content: const Text('Go to $webAccountUrl to manage your account.'),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
    ),
  );
}
