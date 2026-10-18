// Mail, the mail app of Silica.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'src/app_info.dart';
import 'src/compose.dart';
import 'src/l10n.dart';
import 'src/service.dart';
import 'src/style.dart';
import 'src/window.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // About Mail and the standard app menu (silica-ui#99).
  SilicaApp.info = appInfo;
  // The toolbar is unified with the window: Ossido draws only the window buttons.
  SilicaWindow.setFullSizeContent(AmalfiToolbarMetrics.toolbarHeight).ignore();
  setMinimumSize().ignore();
  final connection = await connect(Platform.environment);
  // Mail keeps running when its window closes; a reopen shows the main window again on the
  // same mailbox (APP-LC). The engine connection and the mailbox outlive the window.
  final lastMailbox = ValueNotifier<String?>(null);
  // Files named on the command line (Open With, a share) open a message with them attached;
  // later launches reach the running app through the embedder.
  final opened = StreamController<List<String>>.broadcast();
  SilicaApp.onOpen = (files) => opened.add(attachmentsFromArgs(files));
  runApp(
    AppLocalizationsScope(
      // WidgetsApp gives the overlay (menus, tooltips, popovers) and the text-editing
      // shortcuts the Amalfi controls need.
      child: WidgetsApp(
        color: AmalfiColors.light.accentAmalfi,
        debugShowCheckedModeBanner: false,
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, _, _) => builder(context),
        ),
        home: SilicaAppWindow(
          builder: (context) => MailWindow(
            service: connection.service,
            engineError: connection.error,
            sampleData: connection.sample,
            lastMailbox: lastMailbox,
            initialFiles: attachmentsFromArgs(args),
            openedFiles: opened.stream,
          ),
        ),
      ),
    ),
  );
}

/// The smallest window (see [MailMetrics.minimumWindow]).
Future<void> setMinimumSize() =>
    SilicaWindow.setSizeLimits(min: MailMetrics.minimumWindow);

/// How the app reaches its mail.
typedef Connection = ({MailService service, String? error, bool sample});

/// The engine on the session bus, started through D-Bus activation. When it can't start, the
/// window says why and offers to try again: sample mail only with `MAIL_SAMPLE_DATA=1`
/// (development), never instead of the user's mail.
Future<Connection> connect(
  Map<String, String> env, {
  MailService? engine,
}) async {
  if (env['MAIL_SAMPLE_DATA'] == '1') {
    return (
      service: FakeMailService(now: DateTime.now()) as MailService,
      error: null,
      sample: true,
    );
  }
  final service = engine ?? DBusMailService();
  try {
    await service.start();
    await service.listAccounts();
    return (service: service, error: null, sample: false);
  } on MailError catch (e) {
    return (service: service, error: e.message, sample: false);
  }
}
