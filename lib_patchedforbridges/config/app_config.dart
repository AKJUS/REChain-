import 'dart:ui';

import 'package:matrix/matrix.dart';

abstract class AppConfig {
  static String _applicationName = 'REChain';

  static String get applicationName => _applicationName;
  static String? _applicationWelcomeMessage;

  static String? get applicationWelcomeMessage => _applicationWelcomeMessage;
  static String _defaultHomeserver = 'node.marinchik.ink';

  static String get defaultHomeserver => _defaultHomeserver;
  static double fontSizeFactor = 1;
  static const Color chatColor = primaryColor;
  static Color? colorSchemeSeed = primaryColor;
  static const double messageFontSize = 16.0;
  static const bool allowOtherHomeservers = true;
  static const bool enableRegistration = true;
  static const Color primaryColor = Color(0xFF5625BA);
  static const Color primaryColorLight = Color(0xFFCCBDEA);
  static const Color secondaryColor = Color(0xFF41a2bc);
  static String _privacyUrl =
      'https://online.rechain.network/privacy-policy.html';

  static String get privacyUrl => _privacyUrl;
  static const String website = 'https://online.rechain.network';
  static const String enablePushTutorial =
      'https://github.com/sorydima/REChain-/wiki#-how-to-set-up-push-notifications-in-rechain-without-google-services';
  static const String encryptionTutorial =
      'https://github.com/sorydima/REChain-/wiki#2-disable-end-to-end-encryption';
  static const String startChatTutorial =
      'https://github.com/sorydima/REChain-/wiki#basics';
  static const String appId = 'com.rechain.online';
  static const String appOpenUrlScheme = 'com.rechain';
  static String _webBaseUrl = '';

  static String get webBaseUrl => _webBaseUrl;
  static const String sourceCodeUrl =
      'https://github.com/sorydima/REChain-.git';
  static const String supportUrl =
      'https://github.com/sorydima/REChain-/issues';
  static const String changelogUrl =
      'https://raw.githubusercontent.com/sorydima/REChain-/refs/heads/main/CHANGELOG.md';
  static final Uri newIssueUrl = Uri(
    scheme: 'https',
    host: 'github.com',
    path: '/sorydima/REChain-/issues/new',
  );
  static bool renderHtml = true;
  static bool hideRedactedEvents = false;
  static bool hideUnknownEvents = false;
  static bool hideUnimportantStateEvents = false;
  static bool separateChatTypes = true;
  static bool autoplayImages = true;
  static bool sendTypingNotifications = true;
  static bool sendPublicReadReceipts = true;
  static bool swipeRightToLeftToReply = true;
  static bool? sendOnEnter;
  static bool showPresences = true;
  static bool displayNavigationRail = true;
  static bool experimentalVoip = true;
  static const bool hideTypingUsernames = false;
  static const bool hideAllStateEvents = false;
  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'com.rechain://online/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'REChainOnline_Push';
  static const String pushNotificationsAppId = 'com.rechain.online';
  static const double borderRadius = 18.0;
  static const double columnWidth = 360.0;
  static final Uri homeserverList = Uri(
    scheme: 'https',
    host: 'servers.joinmatrix.org',
    path: 'servers.json',
  );

  static void loadFromJson(Map<String, dynamic> json) {
    if (json['chat_color'] != null) {
      try {
        colorSchemeSeed = Color(json['chat_color']);
      } catch (e) {
        Logs().w(
          'Invalid color in config.json! Please, make sure to define the color in this format: "0xffdd0000"!',
          e,
        );
      }
    }
    if (json['application_name'] is String) {
      _applicationName = json['application_name'];
    }
    if (json['application_welcome_message'] is String) {
      _applicationWelcomeMessage = json['application_welcome_message'];
    }
    if (json['default_homeserver'] is String) {
      _defaultHomeserver = json['default_homeserver'];
    }
    if (json['privacy_url'] is String) {
      _privacyUrl = json['privacy_url'];
    }
    if (json['web_base_url'] is String) {
      _webBaseUrl = json['web_base_url'];
    }
    if (json['render_html'] is bool) {
      renderHtml = json['render_html'];
    }
    if (json['hide_redacted_events'] is bool) {
      hideRedactedEvents = json['hide_redacted_events'];
    }
    if (json['hide_unknown_events'] is bool) {
      hideUnknownEvents = json['hide_unknown_events'];
    }
  }
}
