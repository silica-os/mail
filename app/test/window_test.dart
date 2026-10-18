import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_mail/src/compose.dart';
import 'package:silica_mail/src/l10n.dart';
import 'package:silica_mail/src/model.dart';
import 'package:silica_mail/src/service.dart';
import 'package:silica_mail/src/style.dart';
import 'support.dart';
import 'package:silica_mail/src/window.dart';

final DateTime now = DateTime(2026, 10, 14, 15, 30);

Future<FakeMailService> pump(
  WidgetTester tester, {
  FakeMailService? service,
  Locale locale = const Locale('en'),
  List<String>? opened,
  String? engineError,
  bool sampleData = false,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final fake = service ?? FakeMailService(now: now);
  await tester.pumpWidget(
    AppLocalizationsScope(
      locale: locale,
      child: testApp(
        MailWindow(
          service: fake,
          now: () => now,
          openUrl: opened?.add,
          engineError: engineError,
          sampleData: sampleData,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> tapRow(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('row $id')));
  await tester.pumpAndSettle();
}

void main() {
  dividerExtentTests();
  tearDown(() => useLocale(const Locale('en')));

  testWidgets('the inbox lists conversations, newest first, with unread dots', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(AmalfiTitlePiece), findsOneWidget);
    expect(titleOf(tester), 'Inbox');
    // 20 messages in 10 threads (t0…t9); the subtitle counts messages and unread ones.
    final subtitle = subtitleOf(tester);
    expect(subtitle, startsWith('20 messages'));
    expect(find.byKey(const ValueKey('unread dot m0')), findsOneWidget);
    expect(find.byKey(const ValueKey('no selection')), findsOneWidget);
    // The unread count of the inbox in the sidebar.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mailbox inbox')),
        matching: find.byType(AmalfiSidebarBadge),
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting opens the conversation and marks it read', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('row m0')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('reader')), findsOneWidget);
    expect(find.byKey(const ValueKey('subject m0')), findsOneWidget);
    // m0 and m10 share thread t0: both in the reader.
    expect(find.byKey(const ValueKey('subject m10')), findsOneWidget);
    // ML-01b: still unread right after the selection, read ~120 ms later.
    final before = (await fake.listMessages(
      const ListQuery('inbox'),
    )).firstWhere((r) => r.id == 'm0');
    expect(before.unread, isTrue);
    await tester.pump(const Duration(milliseconds: 130));
    final row = (await fake.listMessages(
      const ListQuery('inbox'),
    )).firstWhere((r) => r.id == 'm0');
    expect(row.unread, isFalse);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unread dot m0')), findsNothing);
  });

  testWidgets('remote content stays blocked until the user loads it', (
    tester,
  ) async {
    final opened = <String>[];
    await pump(tester, opened: opened);
    // m1 has HTML with a remote image (thread t1, with m11).
    await tapRow(tester, 'm1');
    expect(find.byKey(const ValueKey('remote banner m1')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byKey(const ValueKey('load remote m1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('remote banner m1')), findsNothing);
  });

  testWidgets('search lists the matching messages; Escape goes back', (
    tester,
  ) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search field')), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'lunch');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(titleOf(tester), 'Searching');
    expect(subtitleOf(tester), startsWith('All Mailboxes, '));
    expect(find.text('Lunch on Friday?'), findsWidgets);
    expect(find.text('Notes from Tuesday'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(titleOf(tester), 'Inbox');
  });

  testWidgets('reply is prefilled and sends through the engine', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tapRow(tester, 'm2');
    await tapSegment(tester, 'reply group', 0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    // The recipient is a token, the field after it is empty.
    expect(
      tester
          .widget<AmalfiToken>(find.byKey(const ValueKey('compose to token 0')))
          .label,
      'Lena Fischer',
    );
    expect(
      tester
          .widget<EditableText>(find.byKey(const ValueKey('compose to')))
          .controller
          .text,
      isEmpty,
    );
    final subject = tester.widget<EditableText>(
      find.byKey(const ValueKey('compose subject')),
    );
    expect(subject.controller.text, 'Re: Lunch on Friday?');
    final body = tester.widget<EditableText>(
      find.byKey(const ValueKey('compose body')),
    );
    expect(body.controller.text, contains('Lena Fischer wrote:'));
    expect(body.controller.text, contains('> Hi Alex,'));
    await tester.tap(find.byKey(const ValueKey('compose send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsNothing);
    expect(fake.sent.single.subject, 'Re: Lunch on Friday?');
    expect(fake.sent.single.inReplyTo, isNotNull);
  });

  testWidgets('the composer is 832 × 720 and Send waits for a recipient', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('composer panel'));
    expect(tester.getSize(panel), const Size(832, 720));
    double sendOpacity() => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byKey(const ValueKey('compose send')),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;
    expect(sendOpacity(), 0.35);
    await tester.enterText(
      find.byKey(const ValueKey('compose to')),
      'sam@example.net',
    );
    await tester.pump();
    expect(sendOpacity(), 1);
  });

  testWidgets('a new message without recipients is not sent', (tester) async {
    final fake = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compose send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compose error')), findsOneWidget);
    expect(fake.sent, isEmpty);
  });

  testWidgets('delete moves the message to the Trash and selects the next', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tapRow(tester, 'm3');
    await tapSegment(tester, 'triage group', 1);
    await tester.pump();
    await tester.pump();
    final trash = await fake.listMessages(const ListQuery('trash'));
    expect(trash.map((r) => r.id), contains('m3'));
    // ML-01b: no animation; the next message is selected at once, the reader follows
    // ~120 ms later.
    expect(find.byKey(const ValueKey('row m3')), findsNothing);
    expect(find.byKey(const ValueKey('selection m4')), findsOneWidget);
    expect(find.byKey(const ValueKey('subject m4')), findsNothing);
    await tester.pump(const Duration(milliseconds: 130));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reader')), findsOneWidget);
    expect(find.byKey(const ValueKey('subject m4')), findsOneWidget);
  });

  testWidgets('right click on a row: the context menu deletes', (tester) async {
    final fake = await pump(tester);
    final at = tester.getCenter(find.byKey(const ValueKey('row m3')));
    final gesture = await tester.startGesture(
      at,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Reply All'), findsOneWidget);
    expect(find.text('Move to'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final trash = await fake.listMessages(const ListQuery('trash'));
    expect(trash.map((r) => r.id), contains('m3'));
  });

  testWidgets('right click on a mailbox: mark all as read, synchronize', (
    tester,
  ) async {
    await pump(tester);
    final box = find.byKey(const ValueKey('mailbox menu inbox'));
    final at = tester.getCenter(box);
    final gesture = await tester.startGesture(
      at,
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Mark All Messages as Read'), findsOneWidget);
    expect(find.textContaining('Synchronize'), findsOneWidget);
  });

  testWidgets('first run: without accounts the setup opens by itself', (
    tester,
  ) async {
    final fake = FakeMailService(now: now, sample: false);
    await pump(tester, service: fake);
    expect(find.byKey(const ValueKey('account setup')), findsOneWidget);
    // Cancel leaves the empty window, which offers the setup again.
    await tester.tap(find.byKey(const ValueKey('setup cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account setup')), findsNothing);
    expect(find.byKey(const ValueKey('no accounts')), findsOneWidget);
    await tester.tap(find.text('Add Account').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account setup')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('setup name')), 'Robin');
    await tester.enterText(
      find.byKey(const ValueKey('setup address')),
      'robin@example.com',
    );
    // The address enables Continue on the next frame.
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('setup imap'))).data,
      'Incoming server: imap.example.com:993',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account setup')), findsNothing);
    expect((await fake.listAccounts()).single.address, 'robin@example.com');
    // The engine needs the security of each server.
    expect(fake.added.single.toJson()['imap'], {
      'host': 'imap.example.com',
      'port': 993,
      'tls': 'tls',
    });
  });

  testWidgets('settings not found: the servers are entered by hand', (
    tester,
  ) async {
    final fake = FakeMailService(now: now, sample: false)
      ..undiscoverable.add('kim@small.example');
    await pump(tester, service: fake);
    await tester.enterText(
      find.byKey(const ValueKey('setup address')),
      'kim@small.example',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup error')), findsOneWidget);
    // The usual names are proposed.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('setup imap host')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'imap.small.example',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup imap host')),
      'mx.small.example',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup smtp port')),
      '587',
    );
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('setup imap'))).data,
      'Incoming server: mx.small.example:993',
    );
    await tester.enterText(
      find.byKey(const ValueKey('setup password')),
      'secret',
    );
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    final config = fake.added.single;
    expect(config.imapHost, 'mx.small.example');
    expect(config.smtpTls, MailTls.starttls);
    expect(config.username, 'kim@small.example');
  });

  testWidgets('a bad port keeps the manual form', (tester) async {
    final fake = FakeMailService(now: now, sample: false)
      ..undiscoverable.add('kim@small.example');
    await pump(tester, service: fake);
    await tester.enterText(
      find.byKey(const ValueKey('setup address')),
      'kim@small.example',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('setup imap port')), 'x');
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup imap host')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('setup error'))).data,
      'Enter both servers and their ports (1–65535).',
    );
  });

  testWidgets('Microsoft servers are said not supported, without a password', (
    tester,
  ) async {
    final fake = FakeMailService(now: now, sample: false);
    await pump(tester, service: fake);
    await tester.enterText(
      find.byKey(const ValueKey('setup address')),
      'sam@outlook.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setup provider note')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup password')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(fake.added, isEmpty);
  });

  testWidgets('Google servers ask for an app password', (tester) async {
    final fake = FakeMailService(now: now, sample: false);
    await pump(tester, service: fake);
    await tester.enterText(
      find.byKey(const ValueKey('setup address')),
      'sam@gmail.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup continue')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('setup provider note')))
          .data,
      contains('app password'),
    );
    expect(find.byKey(const ValueKey('setup password')), findsOneWidget);
  });

  testWidgets('engine unavailable: the window says so and tries again', (
    tester,
  ) async {
    final fake = FakeMailService(
      now: now,
      unavailable: 'org.freedesktop.DBus.Error.ServiceUnknown',
    );
    await pump(
      tester,
      service: fake,
      engineError: 'org.freedesktop.DBus.Error.ServiceUnknown',
    );
    expect(find.byKey(const ValueKey('engine unavailable')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('engine error'))).data,
      'org.freedesktop.DBus.Error.ServiceUnknown',
    );
    // No sample mail and no setup in its place.
    expect(find.byKey(const ValueKey('row m1')), findsNothing);
    expect(find.byKey(const ValueKey('account setup')), findsNothing);
    // Still down: the error stays.
    await tester.tap(find.byKey(const ValueKey('engine retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('engine unavailable')), findsOneWidget);
    // Up again: the mail appears.
    fake.unavailable = null;
    await tester.tap(find.byKey(const ValueKey('engine retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('engine unavailable')), findsNothing);
    expect(titleOf(tester), 'Inbox');
  });

  testWidgets('sample data is labelled as such', (tester) async {
    await pump(tester, sampleData: true);
    expect(
      find.text(
        'Sample mail for development (MAIL_SAMPLE_DATA): no real account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Italian: mailboxes and texts in Italian', (tester) async {
    await pump(tester, locale: const Locale('it'));
    expect(titleOf(tester), 'In arrivo');
    expect(subtitleOf(tester), startsWith('20 messaggi'));
    expect(find.text('Nessun messaggio scelto'), findsOneWidget);
    expect(find.text('Cestino'), findsOneWidget);
  });

  testWidgets('list rows follow the kit: 84 pt rows in a 320 pt list', (
    tester,
  ) async {
    await pump(tester);
    expect(tester.getSize(find.byKey(const ValueKey('row m0'))).height, 84);
    expect(tester.getSize(find.byKey(const ValueKey('sidebar'))).width, 240);
    expect(
      tester.getSize(find.byKey(const ValueKey('message list'))).width,
      320,
    );
    // Apps/Mail/List Row/Unread: the dot is 8 across at x 12, y 12 of the row.
    final dot = find.byKey(const ValueKey('unread dot m0'));
    expect(tester.getSize(dot), const Size(8, 8));
    final row = tester.getTopLeft(find.byKey(const ValueKey('row m0')));
    expect(tester.getTopLeft(dot) - row, const Offset(12, 12));
  });

  testWidgets('a thread expands with Right and collapses with Left', (
    tester,
  ) async {
    await pump(tester);
    await tapRow(tester, 'm0');
    expect(find.byKey(const ValueKey('row m10')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('thread block m0')), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('row m10'))).height, 44);
    // The child opens only its message.
    await tapRow(tester, 'm10');
    expect(find.byKey(const ValueKey('subject m10')), findsOneWidget);
    expect(find.byKey(const ValueKey('subject m0')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('thread count m0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('row m10')), findsNothing);
  });

  testWidgets('the sidebar button hides and shows the sidebar', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('sidebar toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sidebar')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sidebar toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sidebar')), findsOneWidget);
  });

  testWidgets('the sidebar slides on the measured timing and the toggle stays '
      'one widget', (tester) async {
    await pump(tester);
    final toggle = find.byKey(const ValueKey('sidebar toggle'));
    final sidebar = find.byKey(const ValueKey('sidebar'));
    double listLeft() =>
        tester.getRect(find.byKey(const ValueKey('list bar'))).left;
    expect(listLeft(), MailMetrics.sidebarWidth);
    await tester.tap(toggle);
    await tester.pump();
    // Closing: 240 ms on the S curve; halfway through the sidebar is partly out.
    await tester.pump(const Duration(milliseconds: 120));
    expect(toggle, findsOneWidget);
    expect(sidebar, findsOneWidget);
    expect(listLeft(), inExclusiveRange(0, MailMetrics.sidebarWidth));
    await tester.pump(const Duration(milliseconds: 119));
    expect(listLeft(), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 2));
    expect(listLeft(), 0);
    expect(sidebar, findsNothing);
    expect(toggle, findsOneWidget);
    // Opening starts 40 ms after the trigger and takes 230 ms.
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(listLeft(), 0);
    await tester.pump(const Duration(milliseconds: 115));
    expect(listLeft(), inExclusiveRange(0, MailMetrics.sidebarWidth));
    expect(toggle, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 116));
    expect(listLeft(), MailMetrics.sidebarWidth);
    expect(toggle, findsOneWidget);
  });

  testWidgets('the sidebar runs up behind its own section, with the sidebar '
      'button (mail#7)', (tester) async {
    await pump(tester);
    // Apps/Mail/Toolbar Sidebar: 240 × 52, the piece 44 wide at x 188 (the glass
    // button itself 36 × 36 at x 192, y 8).
    expect(
      tester.getRect(find.byKey(const ValueKey('sidebar bar'))),
      const Rect.fromLTWH(0, 0, MailMetrics.sidebarWidth, 52),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('sidebar toggle'))),
      const Rect.fromLTWH(192, 8, 36, 36),
    );
    // Apps/Mail/Sidebar: full height, the first header 60 from the top.
    final panel = find.byKey(const ValueKey('sidebar'));
    expect(tester.getRect(panel), const Rect.fromLTWH(0, 0, 240, 800));
    // Rows are 216 × 32 at x 12, with no gap between them.
    final first = tester.getRect(find.byKey(const ValueKey('mailbox inbox')));
    final second = tester.getRect(find.byKey(const ValueKey('mailbox drafts')));
    expect(first.left, 12);
    expect(first.size, const Size(216, 32));
    expect(first.top, 60 + 28);
    expect(second.top - first.top, 32);
  });

  testWidgets('a subject suggestion searches the subject with a token', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('search field')));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'lunch');
    await tester.pump();
    expect(find.byKey(const ValueKey('search suggestions')), findsOneWidget);
    await tester.tap(find.text('Subject contains: lunch'));
    await tester.pumpAndSettle();
    expect(find.byType(AmalfiToken), findsOneWidget);
    expect(find.byKey(const ValueKey('search suggestions')), findsNothing);
    expect(find.text('Lunch on Friday?'), findsWidgets);
  });

  test('scope filters match the sender or the subject', () {
    final rows = [
      MessageSummary(
        id: 'a',
        thread: '',
        from: const Address('anna@example.com', name: 'Anna'),
        to: const [],
        subject: 'Plans',
        preview: '',
        date: now,
      ),
      MessageSummary(
        id: 'b',
        thread: '',
        from: const Address('marco@example.com', name: 'Marco'),
        to: const [],
        subject: 'Anna’s party',
        preview: '',
        date: now,
      ),
    ];
    expect(filterByScope(rows, 'anna', SearchScope.sender).map((r) => r.id), [
      'a',
    ]);
    expect(filterByScope(rows, 'anna', SearchScope.subject).map((r) => r.id), [
      'b',
    ]);
    expect(filterByScope(rows, 'anna', SearchScope.all), hasLength(2));
  });

  testWidgets('dark appearance and inactive window use their colours', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pump(tester);
    await tapRow(tester, 'm0');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    Color selection() =>
        (tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('selection m0')),
                    )
                    .decoration
                as ShapeDecoration)
            .color!;
    expect(selection(), MailColors.dark.inactiveSelection);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    // Amalfi dark accent.
    expect(selection(), const Color(0xFF3D95FF));
    expect(MailFlagCheck.ok, isTrue);
  });

  testWidgets('the composer opens at 98.8 % and settles at 100 % (ML-01b)', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pump();
    final panel = find.byKey(const ValueKey('composer panel'));
    double width() =>
        tester.getBottomRight(panel).dx - tester.getTopLeft(panel).dx;
    expect(width(), closeTo(832 * 0.988, 0.5));
    await tester.pump(const Duration(milliseconds: 60));
    expect(width(), greaterThan(832));
    expect(width(), lessThanOrEqualTo(834.01));
    await tester.pumpAndSettle();
    expect(width(), closeTo(832, 0.01));
    expect(composerOpenScale(0), 0.988);
    expect(composerOpenScale(1), 1);
  });

  testWidgets(
    'sending lifts the composer straight up at 3.3 pt/ms after 100 ms',
    (tester) async {
      final fake = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('compose')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('compose to')),
        'sam@example.net',
      );
      await tester.pump();
      final panel = find.byKey(const ValueKey('composer panel'));
      final top = tester.getTopLeft(panel).dy;
      final width = tester.getSize(panel).width;
      await tester.tap(find.byKey(const ValueKey('compose send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.getTopLeft(panel).dy, closeTo(top, 0.01));
      await tester.pump(const Duration(milliseconds: 60));
      // ~50 ms into the lift: ~165 pt higher, same size (no scale, no fade).
      expect(tester.getTopLeft(panel).dy, lessThan(top - 100));
      expect(
        tester.getBottomRight(panel).dx - tester.getTopLeft(panel).dx,
        closeTo(width, 0.01),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('composer')), findsNothing);
      expect(fake.sent.single.to.single.address, 'sam@example.net');
    },
  );

  testWidgets('Escape closes the composer with a short fade', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('compose')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsNothing);
  });

  testWidgets(
    'dark appearance: HTML mail keeps a white page, plain text does not',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pump(tester);
      await tapRow(tester, 'm1');
      expect(find.byKey(const ValueKey('html page')), findsWidgets);
      await tapRow(tester, 'm0');
      expect(find.byKey(const ValueKey('html page')), findsNothing);
    },
  );

  testWidgets(
    'closing the window keeps Mail; a reopen shows the same mailbox',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(SilicaApp.reset);
      final fake = FakeMailService(now: now);
      final lastMailbox = ValueNotifier<String?>(null);
      await tester.pumpWidget(
        AppLocalizationsScope(
          locale: const Locale('en'),
          child: testApp(
            SilicaAppWindow(
              builder: (context) => MailWindow(
                service: fake,
                now: () => now,
                lastMailbox: lastMailbox,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mailbox sent')));
      await tester.pumpAndSettle();
      expect(lastMailbox.value, 'sent');
      await SilicaApp.handle('lastWindowClosed', null);
      await tester.pump();
      expect(find.byType(MailWindow), findsNothing);
      await SilicaApp.handle('reopen', {'windowless': true});
      await tester.pumpAndSettle();
      expect(find.byType(MailWindow), findsOneWidget);
      expect(titleOf(tester), 'Sent');
    },
  );
}

/// Keeps the model import used (flags are checked through the fake above).
abstract final class MailFlagCheck {
  static bool get ok => MessageFlag.values.length == 4;
}

void dividerExtentTests() {
  testWidgets('the list/message divider runs from the top of the window', (
    tester,
  ) async {
    await pump(tester);
    final lines = find.byType(AmalfiWindowSeparator);
    expect(lines, findsWidgets);
    final window = tester.getRect(find.byType(MailWindow));
    for (final e in lines.evaluate()) {
      final r = tester.getRect(find.byElementPredicate((x) => x == e));
      expect(r.top, window.top);
      expect(r.bottom, window.bottom);
      expect(r.width, 1);
    }
  });
}
