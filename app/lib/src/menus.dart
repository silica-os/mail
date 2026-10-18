// Mail's menus in Silica's menu bar (silica-desktop#175; ML-01 › Menus): the nine menus with
// the items, shortcuts, separators and states as measured. An item whose action is null is
// shown disabled, as macOS shows an unavailable item; a feature the app does not have yet is
// never wired to anything (docs/spec.md › Menus lists them).

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../l10n/app_localizations.dart';

/// A mailbox in the Move to submenu: its name and what choosing it does (null: not offered).
typedef MailboxTarget = ({String name, VoidCallback? run});

/// The mailboxes of one account in the Move to and Copy to submenus.
typedef AccountTargets = ({String account, List<MailboxTarget> mailboxes});

/// What the menus show and do now. Every callback is the app's own action; null disables the
/// item. The model is plain data so that the menus can be tested without the window.
@immutable
class MailMenuModel {
  const MailMenuModel({
    this.composing = false,
    this.editing = false,
    this.canSend = false,
    this.hasMessage = false,
    this.messageUnread = false,
    this.flagged = false,
    this.sidebarShown = true,
    this.sender,
    this.accountName,
    this.accountNames = const [],
    this.moveTargets = const [],
    this.newMessage,
    this.openAccounts,
    this.closeComposer,
    this.search,
    this.deleteMessage,
    this.getNewMail,
    this.syncAccount,
    this.markAllRead,
    this.expandAll,
    this.collapseAll,
    this.toggleSidebar,
    this.goInbox,
    this.goSent,
    this.moveInbox,
    this.moveSent,
    this.previousMailbox,
    this.nextMailbox,
    this.send,
    this.reply,
    this.replyAll,
    this.forward,
    this.toggleRead,
    this.junk,
    this.flag,
    this.clearFlag,
    this.toggleFlag,
    this.archive,
  });

  /// The composer is open: the Message menu starts with Send and the text items apply.
  final bool composing;

  /// A text field has the keyboard (the composer or the search field): Edit acts on it.
  final bool editing;

  /// The composer has a recipient.
  final bool canSend;

  /// A message is selected.
  final bool hasMessage;

  /// The selected message is unread (Mark as Read instead of Mark as Unread).
  final bool messageUnread;

  /// The selected message is flagged.
  final bool flagged;

  final bool sidebarShown;

  /// The sender of the selected message.
  final String? sender;

  /// The account of the shown mailbox (the Synchronize item names it).
  final String? accountName;
  final List<String> accountNames;
  final List<AccountTargets> moveTargets;

  final VoidCallback? newMessage;
  final VoidCallback? openAccounts;
  final VoidCallback? closeComposer;
  final VoidCallback? search;
  final VoidCallback? deleteMessage;
  final VoidCallback? getNewMail;
  final VoidCallback? syncAccount;
  final VoidCallback? markAllRead;
  final VoidCallback? expandAll;
  final VoidCallback? collapseAll;
  final VoidCallback? toggleSidebar;
  final VoidCallback? goInbox;
  final VoidCallback? goSent;
  final VoidCallback? moveInbox;
  final VoidCallback? moveSent;
  final VoidCallback? previousMailbox;
  final VoidCallback? nextMailbox;
  final VoidCallback? send;
  final VoidCallback? reply;
  final VoidCallback? replyAll;
  final VoidCallback? forward;
  final VoidCallback? toggleRead;
  final VoidCallback? junk;
  final VoidCallback? flag;
  final VoidCallback? clearFlag;
  final VoidCallback? toggleFlag;
  final VoidCallback? archive;
}

SingleActivator _k(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
  bool ctrl = false,
}) => SingleActivator(key, meta: true, shift: shift, alt: alt, control: ctrl);

SilicaMenuItem _item(
  String label, {
  SingleActivator? key,
  VoidCallback? run,
  bool checked = false,
}) => SilicaMenuItem(
  label: label,
  shortcut: key,
  onSelected: run,
  enabled: run != null,
  checked: checked,
);

/// An item the app does not offer (yet): shown, grayed.
SilicaMenuItem _off(
  String label, {
  SingleActivator? key,
  bool checked = false,
}) => _item(label, key: key, checked: checked);

SilicaMenu _sub(String label, List<PlatformMenuItem> items, {bool on = true}) =>
    SilicaMenu(label: label, menus: items, enabled: on);

PlatformMenuItemGroup _group(List<PlatformMenuItem> members) =>
    PlatformMenuItemGroup(members: members);

/// The menus Mail publishes, for the state in `m`.
List<PlatformMenuItem> mailMenus(AppLocalizations l, MailMenuModel m) {
  final viewer = !m.composing;
  VoidCallback? inViewer(VoidCallback? run) => viewer ? run : null;
  VoidCallback? onMessage(VoidCallback? run) =>
      viewer && m.hasMessage ? run : null;
  return [
    _appMenu(l, m),
    _fileMenu(l, m),
    _editMenu(l, m, inViewer),
    _viewMenu(l, m, inViewer),
    _mailboxMenu(l, m, inViewer),
    _messageMenu(l, m, onMessage),
    _formatMenu(l, m),
    SilicaMenus.window(
      l.menuWindow,
      items: [
        _group([
          _off(l.menuMessageViewer, key: _k(LogicalKeyboardKey.digit0)),
          _off(l.menuPhotoBrowser),
        ]),
        _group([
          _off(l.menuPreviousRecipients),
          _off(l.menuActivity, key: _k(LogicalKeyboardKey.digit0, alt: true)),
          _off(l.menuConnectionDoctor),
        ]),
      ],
    ),
    SilicaMenu(
      label: l.menuHelp,
      role: SilicaMenuRole.help,
      menus: [
        _group([
          SilicaMenuItem(
            label: l.menuMailHelp,
            role: SilicaMenuItemRole.help,
            shortcut: const CharacterActivator('?', meta: true),
            enabled: false,
          ),
        ]),
        _group([_off(l.menuWhatsNewInMail)]),
      ],
    ),
  ];
}

/// The standard app menu of silica_ui (silica-ui#99): About Mail (the standard About panel),
/// no Settings… (Mail has no settings window yet, so the item is not shown), Accounts… and
/// Add Account…, then the system items.
SilicaMenu _appMenu(AppLocalizations l, MailMenuModel m) => SilicaMenus.app(
  l.appTitle,
  items: [
    _item(l.menuAccountsDots, run: m.openAccounts),
    _group([_item(l.menuAddAccountDots, run: m.openAccounts)]),
  ],
);

SilicaMenu _fileMenu(AppLocalizations l, MailMenuModel m) {
  return SilicaMenu(
    label: l.menuFile,
    menus: [
      _group([
        _item(
          l.newMessage,
          key: _k(LogicalKeyboardKey.keyN),
          run: m.newMessage,
        ),
        _off(
          l.menuNewViewerWindow,
          key: _k(LogicalKeyboardKey.keyN, alt: true),
        ),
        _off(
          m.hasMessage ? l.menuOpenMessage : l.menuOpenMessages,
          key: _k(LogicalKeyboardKey.keyO),
        ),
      ]),
      _group([
        if (m.composing)
          _item(
            l.menuClose,
            key: _k(LogicalKeyboardKey.keyW),
            run: m.closeComposer,
          )
        else
          const SilicaMenuItem.system(SilicaMenuItemRole.close),
        _off(l.menuSave, key: _k(LogicalKeyboardKey.keyS)),
        _off(l.menuSaveAsDots, key: _k(LogicalKeyboardKey.keyS, shift: true)),
      ]),
      _group([
        _off(
          l.menuAttachFilesDots,
          key: _k(LogicalKeyboardKey.keyA, shift: true),
        ),
        _off(l.menuSaveAttachmentsDots),
        _off(l.menuQuickLookAttachmentsDots, key: _k(LogicalKeyboardKey.keyY)),
      ]),
      _group([_off(l.menuImportMailboxesDots)]),
      _group([_off(l.menuExportAsPDFDots)]),
      _group([_off(l.menuPrintDots, key: _k(LogicalKeyboardKey.keyP))]),
    ],
  );
}

SilicaMenu _editMenu(
  AppLocalizations l,
  MailMenuModel m,
  VoidCallback? Function(VoidCallback?) inViewer,
) {
  const cause = SelectionChangedCause.keyboard;
  // The standard items act on the text field that has the keyboard through Flutter's text
  // editing intents; with no field they are shown disabled.
  SilicaMenuItem text(
    SilicaMenuItemRole role,
    Intent intent,
    SingleActivator? key,
  ) => m.editing
      ? SilicaMenuItem(role: role, shortcut: key, onSelectedIntent: intent)
      : SilicaMenuItem(role: role, shortcut: key, enabled: false);
  final viewer = !m.composing;
  final delete = m.editing ? null : m.deleteMessage;
  return SilicaMenu(
    label: l.menuEdit,
    menus: [
      _group([
        text(
          SilicaMenuItemRole.undo,
          const UndoTextIntent(cause),
          _k(LogicalKeyboardKey.keyZ),
        ),
        text(
          SilicaMenuItemRole.redo,
          const RedoTextIntent(cause),
          _k(LogicalKeyboardKey.keyZ, shift: true),
        ),
      ]),
      _group([
        text(
          SilicaMenuItemRole.cut,
          const CopySelectionTextIntent.cut(cause),
          _k(LogicalKeyboardKey.keyX),
        ),
        text(
          SilicaMenuItemRole.copy,
          CopySelectionTextIntent.copy,
          _k(LogicalKeyboardKey.keyC),
        ),
        text(
          SilicaMenuItemRole.paste,
          const PasteTextIntent(cause),
          _k(LogicalKeyboardKey.keyV),
        ),
        SilicaMenuItem(
          role: SilicaMenuItemRole.delete,
          shortcut: _k(LogicalKeyboardKey.backspace),
          onSelected: delete,
          enabled: delete != null,
        ),
        text(
          SilicaMenuItemRole.selectAll,
          const SelectAllTextIntent(cause),
          _k(LogicalKeyboardKey.keyA),
        ),
        _off(
          l.menuComplete,
          key: const SingleActivator(LogicalKeyboardKey.escape, alt: true),
        ),
      ]),
      _group([
        _off(
          l.menuPasteAsQuotation,
          key: _k(LogicalKeyboardKey.keyV, shift: true),
        ),
        _off(
          l.menuPasteAndMatchStyle,
          key: _k(LogicalKeyboardKey.keyV, shift: true, alt: true),
        ),
      ]),
      _group([
        _off(
          l.menuAppendSelectedMessages,
          key: _k(LogicalKeyboardKey.keyI, alt: true),
        ),
        _off(l.menuAddLinkDots, key: _k(LogicalKeyboardKey.keyK)),
        _sub(l.menuAttachments, [
          _off(l.menuAlwaysSendWindowsFriendlyAttachments, checked: true),
          _off(l.menuAlwaysInsertAttachmentsAtEndOfMessage),
        ]),
        _sub(l.menuIncludeAttachmentsWithReplies, [
          _off(l.menuAlways),
          _off(l.menuNever),
          _off(l.menuWhenAddingRecipients, checked: true),
          _off(l.menuAsk),
        ]),
      ]),
      _group([
        _sub(l.menuFind, [
          _group([
            _item(
              l.menuMailboxSearch,
              key: _k(LogicalKeyboardKey.keyF, alt: true),
              run: inViewer(m.search),
            ),
          ]),
          _group([
            // Until a message can be searched on its own, Find… starts the mailbox search.
            _item(
              l.menuFindDots,
              key: _k(LogicalKeyboardKey.keyF),
              run: inViewer(m.search),
            ),
            _off(l.menuFindNext, key: _k(LogicalKeyboardKey.keyG)),
            _off(
              l.menuFindPrevious,
              key: _k(LogicalKeyboardKey.keyG, shift: true),
            ),
          ]),
          _group([
            _off(l.menuUseSelectionForFind, key: _k(LogicalKeyboardKey.keyE)),
            _off(l.menuJumpToSelection, key: _k(LogicalKeyboardKey.keyJ)),
            _off(l.menuJumpToTop, key: _k(LogicalKeyboardKey.keyT, ctrl: true)),
          ]),
        ], on: viewer),
      ]),
      _group([
        _sub(l.menuWritingTools, [
          _group([_off(l.menuShowWritingTools)]),
          _group([_off(l.menuProofread), _off(l.menuRewrite)]),
          _group([
            _off(l.menuMakeFriendly),
            _off(l.menuMakeProfessional),
            _off(l.menuMakeConcise),
          ]),
          _group([
            _off(l.menuSummarize),
            _off(l.menuCreateKeyPoints),
            _off(l.menuMakeList),
            _off(l.menuMakeTable),
          ]),
          _group([_off(l.menuComposeDots)]),
        ], on: viewer),
        _sub(l.menuSpellingAndGrammar, [
          _off(l.menuShowSpellingAndGrammar, key: _k(LogicalKeyboardKey.colon)),
          _off(l.menuCheckDocumentNow, key: _k(LogicalKeyboardKey.semicolon)),
          _sub(l.menuCheckSpelling, [
            _off(l.menuWhileTyping),
            _off(l.menuBeforeSending),
            _off(l.menuNever),
          ], on: false),
          _off(l.menuCheckGrammarWithSpelling),
          _off(l.menuCorrectSpellingAutomatically),
        ]),
        _sub(l.menuSubstitutions, [
          _group([_off(l.menuShowSubstitutions)]),
          _group([
            _off(l.menuSmartCopyPaste),
            _off(l.menuSmartQuotes),
            _off(l.menuSmartLists),
            _off(l.menuSmartDashes),
            _off(l.menuSmartLinks),
            _off(l.menuTextReplacement),
          ]),
        ]),
        _sub(l.menuTransformations, [
          _off(l.menuMakeUpperCase),
          _off(l.menuMakeLowerCase),
          _off(l.menuCapitalize),
        ]),
        _sub(l.menuSpeech, [
          _off(l.menuStartSpeaking),
          _off(l.menuStopSpeaking),
        ]),
      ]),
      _group([
        _sub(l.menuAutoFill, [
          _off(l.menuContactDots),
          _off(l.menuPasswordsDots),
          _off(l.menuCreditCardDots),
        ]),
        _off(l.menuStartDictationDots),
        _off(l.menuEmojiSymbols),
      ]),
    ],
  );
}

SilicaMenu _viewMenu(
  AppLocalizations l,
  MailMenuModel m,
  VoidCallback? Function(VoidCallback?) inViewer,
) {
  return SilicaMenu(
    label: l.menuView,
    menus: [
      _group([_off(l.menuShowTabBar), _off(l.menuShowAllTabs)]),
      _group([
        _sub(l.menuFilter, [
          _group([
            _off(l.menuEnableMessageFilter, key: _k(LogicalKeyboardKey.keyL)),
          ]),
          _group([
            _off(l.menuInclude),
            _off(l.menuUnread, checked: true),
            _off(l.menuFlagged),
          ]),
          _group([_off(l.menuAddressed), _off(l.menuToMe), _off(l.menuCcMe)]),
          _group([
            _off(l.menuOnlyMailWithAttachments),
            _off(l.menuOnlyFromVIP),
          ]),
        ], on: m.composing == false),
        _sub(l.menuSortBy, [
          _off(l.menuAttachments),
          _off(l.menuDate, checked: true),
          _off(l.menuDateSent),
          _off(l.menuRemindMe),
          _off(l.menuSendLater),
          _off(l.menuFlags),
          _off(l.menuFrom),
          _off(l.menuSize),
          _off(l.menuSubject),
          _off(l.menuTo),
          _off(l.menuSortUnread),
          _group([
            _off(l.menuOldestMessageOnTop),
            _off(l.menuNewestMessageOnTop, checked: true),
          ]),
        ], on: m.composing == false),
      ]),
      _group([
        _off(l.menuUseColumnLayout),
        _off(l.menuShowBottomPreview),
        _off(l.menuShowDateAndTime),
        _off(l.menuShowToCcLabel),
        _off(l.menuShowMessageSize),
        _off(l.menuShowContactPhoto),
        _off(l.menuShowMailCategories),
        _off(l.menuShowPriorityMessages),
        _off(l.menuAboutCategoriesDots),
      ]),
      _group([
        _off(l.menuHighlightConversations),
        _off(l.menuOrganizeByConversation, checked: true),
        _item(l.menuExpandAllConversations, run: inViewer(m.expandAll)),
        _item(l.menuCollapseAllConversations, run: inViewer(m.collapseAll)),
      ]),
      _group([
        _off(l.menuCcAddressField, checked: true),
        _off(
          l.menuBccAddressField,
          key: _k(LogicalKeyboardKey.keyB, alt: true),
        ),
        _off(
          l.menuReplyToAddressField,
          key: _k(LogicalKeyboardKey.keyR, alt: true),
        ),
        _off(l.menuPriorityField),
      ]),
      _group([
        _sub(l.menuMessage, [
          _off(l.menuShowWithLightBackground),
          _off(l.menuAllHeaders, key: _k(LogicalKeyboardKey.keyH, shift: true)),
          _off(l.menuRawSource, key: _k(LogicalKeyboardKey.keyU, alt: true)),
        ], on: m.composing == false),
        _off(l.menuHideRelatedMessages),
      ]),
      _group([
        _item(
          m.sidebarShown ? l.menuHideSidebar : l.menuShowSidebar,
          key: _k(LogicalKeyboardKey.keyS, ctrl: true),
          run: inViewer(m.toggleSidebar),
        ),
        _off(l.menuHideToolbar, key: _k(LogicalKeyboardKey.keyT, alt: true)),
        _off(l.menuCustomizeToolbarDots),
        _off(
          l.menuShowFavoritesBar,
          key: _k(LogicalKeyboardKey.keyH, shift: true, alt: true),
        ),
        const SilicaMenuItem.system(SilicaMenuItemRole.fullScreen),
      ]),
    ],
  );
}

SilicaMenu _mailboxMenu(
  AppLocalizations l,
  MailMenuModel m,
  VoidCallback? Function(VoidCallback?) inViewer,
) {
  final account = m.accountName;
  return SilicaMenu(
    label: l.menuMailbox,
    menus: [
      _group([
        _item(
          l.menuGetNewMail,
          key: _k(LogicalKeyboardKey.keyN, shift: true),
          run: m.getNewMail,
        ),
        if (account != null)
          _item(l.menuSynchronize(account), run: m.syncAccount),
        _item(l.menuMarkAllMessagesAsRead, run: inViewer(m.markAllRead)),
      ]),
      _group([
        _sub(l.menuEraseDeletedItems, [
          _off(
            l.menuInAllAccountsDots,
            key: _k(LogicalKeyboardKey.backspace, shift: true),
          ),
          _off(
            l.menuInAllAccounts,
            key: _k(LogicalKeyboardKey.backspace, shift: true, alt: true),
          ),
          if (m.accountNames.isNotEmpty)
            _group([for (final name in m.accountNames) _off('$name…')]),
        ]),
        _off(l.menuEraseJunkMail, key: _k(LogicalKeyboardKey.keyJ, alt: true)),
      ]),
      _group([
        _off(l.menuNewMailboxDots),
        _off(l.menuAddFavoriteMailboxDots),
        _off(l.menuNewSmartMailboxDots),
        _off(l.menuEditSmartMailboxDots),
        _off(l.menuDuplicateSmartMailbox),
        _off(l.menuNewSmartMailboxFolderDots),
        _off(l.menuRenameMailboxDots),
        _off(l.menuDeleteMailboxDots),
        _off(l.menuExportMailboxDots),
      ]),
      _group([
        _sub(l.menuGoToFavoriteMailbox, [
          _item(
            l.mailboxInbox,
            key: _k(LogicalKeyboardKey.digit1),
            run: inViewer(m.goInbox),
          ),
          _item(
            l.mailboxSent,
            key: _k(LogicalKeyboardKey.digit2),
            run: inViewer(m.goSent),
          ),
        ]),
        _sub(l.menuMoveToFavoriteMailbox, [
          _item(
            l.mailboxInbox,
            key: _k(LogicalKeyboardKey.digit1, ctrl: true),
            run: inViewer(m.moveInbox),
          ),
          _item(
            l.mailboxSent,
            key: _k(LogicalKeyboardKey.digit2, ctrl: true),
            run: inViewer(m.moveSent),
          ),
        ]),
        _item(
          l.menuGoToPreviousMailbox,
          key: _k(LogicalKeyboardKey.bracketLeft, ctrl: true),
          run: inViewer(m.previousMailbox),
        ),
        _item(
          l.menuGoToNextMailbox,
          key: _k(LogicalKeyboardKey.bracketRight, ctrl: true),
          run: inViewer(m.nextMailbox),
        ),
      ]),
      _group([_off(l.menuRebuild)]),
    ],
  );
}

SilicaMenu _messageMenu(
  AppLocalizations l,
  MailMenuModel m,
  VoidCallback? Function(VoidCallback?) onMessage,
) {
  final viewer = !m.composing;
  final sender = m.sender;
  // The Move to and Copy to submenus: the favourites, then each account's mailboxes under
  // its name (a disabled label). Copy to is shown, but the engine can't copy yet.
  List<PlatformMenuItem> targets({required bool move}) => [
    _group([
      _item(l.mailboxInbox, run: move ? onMessage(m.moveInbox) : null),
      _item(l.mailboxSent, run: move ? onMessage(m.moveSent) : null),
    ]),
    for (final a in m.moveTargets)
      _group([
        _off(a.account),
        for (final t in a.mailboxes)
          _item(t.name, run: move ? onMessage(t.run) : null),
      ]),
  ];
  return SilicaMenu(
    label: l.menuMessage,
    menus: [
      _group([
        if (m.composing) ...[
          _item(
            l.menuSend,
            key: _k(LogicalKeyboardKey.keyD, shift: true),
            run: m.canSend ? m.send : null,
          ),
          _sub(l.menuSendLater, [
            _off(l.menuSend2100Tonight),
            _off(l.menuSend0800Tomorrow),
            _off(l.menuSendLaterDots),
          ], on: false),
        ] else
          _off(l.menuSendAgain, key: _k(LogicalKeyboardKey.keyD, shift: true)),
      ]),
      _group([
        _item(
          l.reply,
          key: _k(LogicalKeyboardKey.keyR),
          run: onMessage(m.reply),
        ),
        _item(
          l.replyAll,
          key: _k(LogicalKeyboardKey.keyR, shift: true),
          run: onMessage(m.replyAll),
        ),
        _item(
          l.forward,
          key: _k(LogicalKeyboardKey.keyF, shift: true),
          run: onMessage(m.forward),
        ),
        _off(l.menuForwardAsAttachment),
        _off(l.menuRedirect, key: _k(LogicalKeyboardKey.keyE, shift: true)),
      ]),
      _group([
        _sub(l.menuRemindMe, [
          _off(l.menuRemindMeIn1Hour),
          _off(l.menuRemindMeTonight),
          _off(l.menuRemindMeTomorrow),
          _off(l.menuRemindMeLaterDots),
          _group([_off(l.menuClearReminder)]),
        ], on: viewer && m.hasMessage),
        _off(l.menuIgnoreFollowUp),
      ]),
      _group([
        _item(
          m.messageUnread ? l.menuMarkAsRead : l.menuMarkAsUnread,
          key: _k(LogicalKeyboardKey.keyU, shift: true),
          run: onMessage(m.toggleRead),
        ),
        _item(
          l.menuMoveToJunk,
          key: _k(LogicalKeyboardKey.keyJ, shift: true),
          run: onMessage(m.junk),
        ),
        _off(
          l.menuMute,
          key: const SingleActivator(
            LogicalKeyboardKey.keyM,
            control: true,
            shift: true,
          ),
        ),
        _sub(l.menuFlag, [
          _item(
            l.menuOrange,
            checked: m.flagged,
            run: m.flagged ? null : onMessage(m.flag),
          ),
          _off(l.menuRed),
          _off(l.menuPurple),
          _off(l.menuBlue),
          _off(l.menuYellow),
          _off(l.menuGreen),
          _off(l.menuGray),
          _group([
            _item(
              l.menuClearFlag,
              run: m.flagged ? onMessage(m.clearFlag) : null,
            ),
            _item(
              l.menuToggleFlag,
              key: _k(LogicalKeyboardKey.keyL, shift: true),
              run: onMessage(m.toggleFlag),
            ),
          ]),
        ], on: viewer && m.hasMessage),
        _sub(l.menuSetPriority, [
          _off(l.menuLow),
          _off(l.menuNormal),
          _off(l.menuHigh),
        ], on: false),
      ]),
      _group([
        _item(
          l.archive,
          key: _k(LogicalKeyboardKey.keyA, ctrl: true),
          run: onMessage(m.archive),
        ),
        _off(
          l.menuMoveToPredictedMailbox,
          key: _k(LogicalKeyboardKey.keyM, ctrl: true),
        ),
        _sub(l.menuMoveTo, targets(move: true), on: viewer && m.hasMessage),
        _sub(l.menuCopyTo, targets(move: false), on: viewer && m.hasMessage),
        _off(l.menuMoveAgain),
      ]),
      _group([
        _off(l.menuApplyRules, key: _k(LogicalKeyboardKey.keyL, alt: true)),
        _off(l.menuAddSenderToContacts),
        _sub(l.menuCategorizeSender, [
          if (sender != null) _off(l.menuCategorizeAll(sender)),
          _off(l.menuAutomatically, checked: true),
          _group([
            _off(l.menuAlwaysCategorizeAs),
            _off(l.menuPrimary),
            _off(l.menuTransactions),
            _off(l.menuUpdates),
            _off(l.menuPromotions),
          ]),
        ], on: false),
      ]),
      _group([_off(l.menuRemoveAttachments)]),
    ],
  );
}

SilicaMenu _formatMenu(AppLocalizations l, MailMenuModel m) {
  return SilicaMenu(
    label: l.menuFormat,
    menus: [
      _group([
        _off(l.menuShowFonts, key: _k(LogicalKeyboardKey.keyT)),
        _off(l.menuShowColors, key: _k(LogicalKeyboardKey.keyC, shift: true)),
      ]),
      _group([
        _sub(l.menuLists, [
          _off(l.menuInsertBulletedList),
          _off(l.menuInsertNumberedList),
          _off(l.menuRemoveListFormatting),
          _group([
            _off(l.menuIncreaseListLevel),
            _off(l.menuDecreaseListLevel),
          ]),
          _group([_off(l.menuConvertToNumberedList)]),
        ], on: false),
        _sub(l.menuStyle, [
          _group([
            _off(l.menuBold, key: _k(LogicalKeyboardKey.keyB)),
            _off(l.menuItalic, key: _k(LogicalKeyboardKey.keyI)),
            _off(l.menuUnderline, key: _k(LogicalKeyboardKey.keyU)),
            _off(l.menuOutline),
          ]),
          _group([
            _off(l.menuBigger, key: _k(LogicalKeyboardKey.add)),
            _off(l.menuSmaller, key: _k(LogicalKeyboardKey.minus)),
          ]),
          _group([
            _off(l.menuCopyStyle, key: _k(LogicalKeyboardKey.keyC, alt: true)),
            _off(l.menuPasteStyle, key: _k(LogicalKeyboardKey.keyV, alt: true)),
            _off(l.menuRemoveStyle),
          ]),
          _group([_off(l.menuStylesDots)]),
        ]),
        _sub(l.menuAlignment, [
          _group([
            _off(l.menuAlignLeft, key: _k(LogicalKeyboardKey.braceLeft)),
            _off(l.menuCenter, key: _k(LogicalKeyboardKey.bar)),
            _off(l.menuJustify),
            _off(l.menuAlignRight, key: _k(LogicalKeyboardKey.braceRight)),
          ]),
          _group([
            _off(l.menuFloatLeft),
            _off(l.menuFloatRight),
            _off(l.menuRemoveFloat),
          ]),
          _sub(l.menuWritingDirection, [
            _off(l.menuParagraph),
            _off(l.menuDefault),
            _off(l.menuLeftToRight),
            _off(l.menuRightToLeft),
            _group([
              _off(l.menuSelection),
              _off(l.menuDefault),
              _off(l.menuLeftToRight),
              _off(l.menuRightToLeft),
            ]),
          ], on: false),
        ], on: false),
      ]),
      _group([
        _sub(l.menuIndentation, [
          _off(l.menuIncrease, key: _k(LogicalKeyboardKey.bracketRight)),
          _off(l.menuDecrease, key: _k(LogicalKeyboardKey.bracketLeft)),
        ], on: false),
        _sub(l.menuQuoteLevel, [
          _off(l.menuIncrease, key: _k(LogicalKeyboardKey.quote)),
          _off(l.menuDecrease, key: _k(LogicalKeyboardKey.quote, alt: true)),
        ], on: false),
      ]),
      _group([
        _off(
          m.composing ? l.menuMakePlainText : l.menuMakeRichText,
          key: _k(LogicalKeyboardKey.keyT, shift: true),
        ),
      ]),
    ],
  );
}
