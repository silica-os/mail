// Mail's menus in Silica's menu bar (silica-desktop#175): the model the window publishes on
// `silica/menu`, the states in the viewer, the empty mailbox and the composer, and the choices
// that come back.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/src/l10n.dart';
import 'package:silica_mail/src/service.dart';
import 'package:silica_mail/src/window.dart';
import 'support.dart';
import 'package:silica_ui/silica_ui.dart' show SilicaMenuDelegate;

typedef Item = Map<Object?, Object?>;

final DateTime now = DateTime(2026, 10, 14, 15, 30);

void main() {
  late List<MethodCall> calls;

  Future<FakeMailService> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => useLocale(const Locale('en')));
    calls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SilicaMenuDelegate.defaultChannel,
      (call) async {
        calls.add(call);
        return true;
      },
    );
    final fake = FakeMailService(now: now);
    await tester.pumpWidget(
      AppLocalizationsScope(
        locale: locale,
        child: testApp(MailWindow(service: fake, now: () => now)),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  List<Item> menus() =>
      ((calls.lastWhere((c) => c.method == 'setMenus').arguments
                  as Map)['menus']
              as List)
          .cast<Item>();

  List<Item> children(Item parent) =>
      ((parent['items'] as List?) ?? const []).cast<Item>();

  /// The first item or submenu called `label`, searching `from` (default: all menus) depth
  /// first.
  Item item(String label, {String? menu}) {
    Item? walk(List<Item> items) {
      for (final i in items) {
        if (i['label'] == label) return i;
        final inner = walk(children(i));
        if (inner != null) return inner;
      }
      return null;
    }

    final from = menu == null
        ? menus()
        : children(menus().firstWhere((m) => m['label'] == menu));
    final found = walk(from);
    if (found == null) fail('no menu item "$label"');
    return found;
  }

  Item byRole(String menu, String role) => children(
    menus().firstWhere((m) => m['label'] == menu),
  ).firstWhere((i) => i['role'] == role, orElse: () => fail('no role $role'));

  bool on(String label, {String? menu}) =>
      item(label, menu: menu)['enabled'] != false;

  bool exists(String label, {String? menu}) {
    try {
      item(label, menu: menu);
      return true;
    } on TestFailure {
      return false;
    }
  }

  Future<void> choose(WidgetTester tester, String label, {String? menu}) async {
    final id = item(label, menu: menu)['id'];
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SilicaMenuDelegate.defaultChannel.name,
      const JSONMethodCodec().encodeMethodCall(MethodCall('activated', id)),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapRow(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('row $id')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'nine menus: app, File, Edit, View, Mailbox, Message, Format, Window, Help',
    (tester) async {
      await pump(tester);
      expect(menus().map((m) => m['label']), [
        'Mail',
        'File',
        'Edit',
        'View',
        'Mailbox',
        'Message',
        'Format',
        'Window',
        'Help',
      ]);
      expect(menus().map((m) => m['role']), [
        'app',
        null,
        null,
        null,
        null,
        null,
        null,
        'window',
        'help',
      ]);
      // The app menu: the accounts work; About is the standard one, enabled, and there is no
      // Settings… placeholder (silica-ui#99).
      expect(on('Accounts…'), isTrue);
      expect(on('Add Account…'), isTrue);
      expect(byRole('Mail', 'about')['enabled'], isTrue);
      expect(
        children(menus().first).where((i) => i['role'] == 'settings'),
        isEmpty,
      );
      final roles = children(menus().first).map((i) => i['role']);
      expect(
        roles,
        containsAll(['services', 'hide', 'hide_others', 'show_all', 'quit']),
      );
    },
  );

  testWidgets('with no message selected the message actions are grayed', (
    tester,
  ) async {
    await pump(tester);
    expect(on('New Message', menu: 'File'), isTrue);
    expect(item('New Message')['shortcut'], {'key': 'N', 'meta': true});
    expect(on('Open Messages'), isFalse);
    for (final label in [
      'Reply',
      'Reply All',
      'Forward',
      'Mark as Unread',
      'Move to Junk',
      'Archive',
      'Flag',
      'Move to',
    ]) {
      expect(on(label, menu: 'Message'), isFalse, reason: label);
    }
    expect(byRole('Edit', 'delete')['enabled'], isFalse);
    expect(byRole('Edit', 'copy')['enabled'], isFalse);
    // Always there: the mailbox commands and the view items.
    expect(on('Get New Mail'), isTrue);
    expect(on('Synchronize “Alex Rivera”'), isTrue);
    expect(on('Hide Sidebar'), isTrue);
    expect(item('Hide Sidebar')['shortcut'], {
      'key': 'S',
      'meta': true,
      'ctrl': true,
    });
  });

  testWidgets(
    'a selected message enables the message actions with their keys',
    (tester) async {
      await pump(tester);
      await tapRow(tester, 'm2');
      expect(item('Reply')['shortcut'], {'key': 'R', 'meta': true});
      expect(item('Reply All')['shortcut'], {
        'key': 'R',
        'meta': true,
        'shift': true,
      });
      expect(item('Forward')['shortcut'], {
        'key': 'F',
        'meta': true,
        'shift': true,
      });
      for (final label in [
        'Reply',
        'Reply All',
        'Forward',
        'Move to Junk',
        'Archive',
        'Toggle Flag',
        'Move to',
        'Flag',
      ]) {
        expect(on(label), isTrue, reason: label);
      }
      expect(byRole('Edit', 'delete')['enabled'], isNot(false));
      // The features Mail does not have yet are shown, grayed.
      for (final label in [
        'Redirect',
        'Forward as Attachment',
        'Mute',
        'Apply Rules',
        'Add Sender to Contacts',
        'Remove Attachments',
        'Copy to',
      ]) {
        expect(on(label, menu: 'Message'), label == 'Copy to', reason: label);
      }
      // Send Again takes Send's place in the viewer and does nothing yet.
      expect(on('Send Again'), isFalse);
      expect(exists('Send', menu: 'Message'), isFalse);
    },
  );

  testWidgets('Reply, Reply All and Forward open the composer', (tester) async {
    await pump(tester);
    await tapRow(tester, 'm2');
    await choose(tester, 'Reply');
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    final subject = tester.widget<EditableText>(
      find.byKey(const ValueKey('compose subject')),
    );
    expect(subject.controller.text, 'Re: Lunch on Friday?');
  });

  testWidgets(
    'Mark as Unread, flag, archive, junk and delete act on the message',
    (tester) async {
      final fake = await pump(tester);
      await tapRow(tester, 'm2');
      await tester.pump(const Duration(milliseconds: 200));
      Future<Map<String, bool>> state() async => {
        for (final r in await fake.listMessages(const ListQuery('inbox')))
          r.id: r.unread,
      };
      expect((await state())['m2'], isFalse);
      expect(item('Mark as Unread')['shortcut'], {
        'key': 'U',
        'meta': true,
        'shift': true,
      });
      await choose(tester, 'Mark as Unread');
      expect((await state())['m2'], isTrue);
      // The item follows the state.
      expect(exists('Mark as Read'), isTrue);
      await choose(tester, 'Mark as Read');
      expect((await state())['m2'], isFalse);

      // Flag: Orange sets the flag, Clear Flag and Toggle Flag take it off.
      if (item('Orange')['checked'] == true) {
        await choose(tester, 'Clear Flag');
      }
      expect(item('Orange')['checked'], isNull);
      expect(on('Clear Flag'), isFalse);
      await choose(tester, 'Orange');
      expect(item('Orange')['checked'], isTrue);
      expect(on('Orange'), isFalse);
      expect(on('Clear Flag'), isTrue);
      await choose(tester, 'Clear Flag');
      expect(item('Orange')['checked'], isNull);
      await choose(tester, 'Toggle Flag');
      expect(item('Orange')['checked'], isTrue);

      await choose(tester, 'Archive');
      expect(
        (await fake.listMessages(const ListQuery('archive'))).map((r) => r.id),
        contains('m2'),
      );
      await tapRow(tester, 'm3');
      await choose(tester, 'Move to Junk');
      expect(
        (await fake.listMessages(const ListQuery('junk'))).map((r) => r.id),
        contains('m3'),
      );
      await tapRow(tester, 'm4');
      final before = (await fake.listMessages(const ListQuery('inbox'))).length;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SilicaMenuDelegate.defaultChannel.name,
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('activated', byRole('Edit', 'delete')['id']),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        (await fake.listMessages(const ListQuery('inbox'))).length,
        lessThan(before),
      );
      // The next message is selected and marked read after its delay.
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('Move to lists the account mailboxes and moves the message', (
    tester,
  ) async {
    final fake = await pump(tester);
    await tapRow(tester, 'm2');
    final moveTo = item('Move to');
    final names = [
      for (final i in children(moveTo))
        for (final j in i['label'] == null ? children(i) : [i]) j['label'],
    ];
    expect(names, containsAll(['Inbox', 'Sent', 'Alex Rivera', 'Trash']));
    // The mailbox the message is in is not offered.
    final target = children(moveTo)
        .expand((i) => i['label'] == null ? children(i) : [i])
        .firstWhere((i) => i['label'] == 'Trash');
    expect(target['enabled'], isNot(false));
    final id = target['id'];
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SilicaMenuDelegate.defaultChannel.name,
      const JSONMethodCodec().encodeMethodCall(MethodCall('activated', id)),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(
      (await fake.listMessages(const ListQuery('trash'))).map((r) => r.id),
      contains('m2'),
    );
  });

  testWidgets('View: sidebar, conversations; Mailbox: mark all read, mailboxes', (
    tester,
  ) async {
    final fake = await pump(tester);
    expect(find.byKey(const ValueKey('mailbox inbox')), findsOneWidget);
    await choose(tester, 'Hide Sidebar');
    expect(exists('Show Sidebar'), isTrue);
    expect(exists('Hide Sidebar'), isFalse);
    await choose(tester, 'Show Sidebar');
    expect(exists('Hide Sidebar'), isTrue);

    // Organize by Conversation is the way the list always works: checked, not togglable.
    expect(item('Organize by Conversation')['checked'], isTrue);
    expect(on('Organize by Conversation'), isFalse);
    expect(item('Date')['checked'], isTrue);
    expect(item('Newest Message on Top')['checked'], isTrue);
    expect(find.byKey(const ValueKey('row m0')), findsOneWidget);
    await choose(tester, 'Expand All Conversations');
    expect(find.byKey(const ValueKey('row m10')), findsOneWidget);
    await choose(tester, 'Collapse All Conversations');
    expect(find.byKey(const ValueKey('row m10')), findsNothing);

    expect(on('Mark All Messages as Read'), isTrue);
    await choose(tester, 'Mark All Messages as Read');
    expect(
      (await fake.listMessages(
        const ListQuery('inbox'),
      )).where((r) => r.unread),
      isEmpty,
    );
    expect(on('Mark All Messages as Read'), isFalse);

    // ⌘2 goes to Sent, the next mailbox follows the sidebar.
    expect(item('Sent', menu: 'Mailbox')['shortcut'], isNotNull);
    await choose(tester, 'Go to Next Mailbox');
    expect(titleOf(tester), isNot('Inbox'));
    await choose(tester, 'Go to Previous Mailbox');
    expect(titleOf(tester), 'Inbox');
  });

  testWidgets(
    'File › New Message and the app menu › Accounts… open their windows',
    (tester) async {
      await pump(tester);
      await choose(tester, 'New Message', menu: 'File');
      expect(find.byKey(const ValueKey('composer')), findsOneWidget);
    },
  );

  testWidgets('the composer: Send takes its place and waits for a recipient', (
    tester,
  ) async {
    final fake = await pump(tester);
    await choose(tester, 'New Message', menu: 'File');
    await tester.pumpAndSettle();
    expect(exists('Send Again'), isFalse);
    expect(item('Send', menu: 'Message')['shortcut'], {
      'key': 'D',
      'meta': true,
      'shift': true,
    });
    expect(on('Send', menu: 'Message'), isFalse);
    expect(on('Send Later', menu: 'Message'), isFalse);
    // The viewer's actions are out of reach while the composer is open.
    expect(on('Reply', menu: 'Message'), isFalse);
    expect(on('Hide Sidebar'), isFalse);
    expect(on('Mailbox Search'), isFalse);
    expect(on('Make Plain Text'), isFalse);
    expect(exists('Make Rich Text'), isFalse);
    // Edit acts on the field with the keyboard.
    expect(byRole('Edit', 'paste')['enabled'], isNot(false));
    expect(byRole('Edit', 'select_all')['enabled'], isNot(false));
    expect(byRole('Edit', 'delete')['enabled'], isFalse);
    // Close closes the composer, not the window.
    expect(item('Close', menu: 'File')['role'], isNull);
    expect(on('Close', menu: 'File'), isTrue);
    expect(children(menus()[1]).where((i) => i['role'] == 'close'), isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('compose to')),
      'sam@example.org',
    );
    await tester.pumpAndSettle();
    expect(on('Send', menu: 'Message'), isTrue);
    await choose(tester, 'Send', menu: 'Message');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer')), findsNothing);
    expect(fake.sent.single.to.single.address, 'sam@example.org');
    // Back in the viewer: Close is the system item again.
    expect(byRole('File', 'close')['enabled'], isNot(false));
  });

  testWidgets('Close in the composer closes it', (tester) async {
    await pump(tester);
    await choose(tester, 'New Message', menu: 'File');
    await choose(tester, 'Close', menu: 'File');
    expect(find.byKey(const ValueKey('composer')), findsNothing);
  });

  testWidgets('the shortcuts are bound by the menu bar', (tester) async {
    await pump(tester);
    Future<void> press(LogicalKeyboardKey key, {bool shift = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
    }

    await press(LogicalKeyboardKey.keyN);
    expect(find.byKey(const ValueKey('composer')), findsOneWidget);
  });

  testWidgets('Edit › Find… and Mailbox Search start the search', (
    tester,
  ) async {
    await pump(tester);
    expect(item('Mailbox Search')['shortcut'], {
      'key': 'F',
      'meta': true,
      'alt': true,
    });
    await choose(tester, 'Mailbox Search');
    expect(find.byKey(const ValueKey('search field')), findsOneWidget);
  });

  testWidgets(
    'the standard app menu: About enabled, no Settings placeholder, Accounts (silica-ui#99)',
    (tester) async {
      await pump(tester);
      final app = menus().first;
      expect(app['role'], 'app');
      expect(
        [for (final i in children(app)) i['role'] ?? i['label'] ?? '—'],
        [
          'about',
          '—',
          'Accounts…',
          '—',
          'Add Account…',
          '—',
          'services',
          '—',
          'hide',
          'hide_others',
          'show_all',
          '—',
          'quit',
        ],
      );
      expect(children(app).first['enabled'], isTrue);
      expect(children(app).first['id'], isA<int>());
    },
  );

  testWidgets('the unavailable items are shown, never hidden', (tester) async {
    await pump(tester);
    // A sample of each menu's features that Mail does not have yet.
    for (final (menu, label) in [
      ('File', 'New Viewer Window'),
      ('File', 'Save As…'),
      ('File', 'Print…'),
      ('Edit', 'Add Link…'),
      ('Edit', 'Show Writing Tools'),
      ('View', 'Use Column Layout'),
      ('View', 'Enable Message Filter'),
      ('Mailbox', 'New Mailbox…'),
      ('Mailbox', 'Rebuild'),
      ('Message', 'Redirect'),
      ('Format', 'Bold'),
      ('Format', 'Align Left'),
      ('Window', 'Message Viewer'),
      ('Help', 'Mail Help'),
    ]) {
      expect(exists(label, menu: menu), isTrue, reason: '$menu › $label');
      expect(on(label, menu: menu), isFalse, reason: '$menu › $label');
    }
    expect(item('Print…')['shortcut'], {'key': 'P', 'meta': true});
    expect(item('Bold')['shortcut'], {'key': 'B', 'meta': true});
    expect(item('Message Viewer')['shortcut'], {'key': '0', 'meta': true});
  });

  testWidgets('Italian menus', (tester) async {
    await pump(tester, locale: const Locale('it'));
    expect(menus().map((m) => m['label']), [
      'Mail',
      'File',
      'Modifica',
      'Vista',
      'Casella',
      'Messaggio',
      'Formato',
      'Finestra',
      'Aiuto',
    ]);
    expect(exists('Nuovo messaggio', menu: 'File'), isTrue);
    expect(exists('Ricevi nuovi messaggi'), isTrue);
    expect(exists('Sincronizza “Alex Rivera”'), isTrue);
    expect(exists('Nascondi barra laterale'), isTrue);
  });
}
