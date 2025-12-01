// lib/services/notification_service.dart
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import '../router.dart';

class NotificationService {
  static const _channelKey = 'keepup_suggestions';
  static const _channelName = 'KeepUp Suggestions';
  static const _channelDesc = 'AI-based contact suggestions and gentle nudges';

  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      // null -> default app icon. Or use 'resource://mipmap/ic_stat_notify'
      null,
      [
        NotificationChannel(
          channelKey: _channelKey,
          channelName: _channelName,
          channelDescription: _channelDesc,
          defaultColor: const Color(0xFF2962FF),
          importance: NotificationImportance.Default,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: false,
    );

    // Handle taps
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceived,
    );
  }

  static Future<void> requestPermissions() async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  /// Show an immediate suggestion (expandable).
  /// - `body` should be a short preview.
  /// - `longText` should be the full AI sentence (shown when expanded).
  /// - We use a stable id per contact to replace previous nudges for that contact.
  static Future<void> showSuggestionNow({
    required String contactId,
    required String title,
    required String body,
    required String prefilledMessage,
    String? longText,
    String? tag, // optional extra dedup key
  }) async {
    final stableId = contactId.hashCode & 0x7fffffff;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: stableId,
        channelKey: _channelKey,
        title: title,
        body: (longText?.trim().isNotEmpty == true) ? longText!.trim() : body,
        summary: body, // small line shown under title; BigText uses body fully
        payload: {'contactId': contactId, 'text': prefilledMessage},
        category: NotificationCategory.Reminder,
        notificationLayout: NotificationLayout.BigText, // expandable
        groupKey: 'keepup_contact_$contactId',
        // `ticker` improves accessibility/announce behavior on some devices
        ticker: 'KeepUp suggestion',
        // Set a tag if you want additional replacement semantics
        // (Awesome will primarily replace by id, tag is optional)
        // Note: older plugin versions don't expose the tag field; safe to ignore
      ),
    );
  }

  /// Schedule at a specific local time (expandable).
  /// Uses the same stable id so the scheduled one also replaces previous for that contact.
  static Future<void> scheduleAt({
    required int id,
    required DateTime when, // local
    required String contactId,
    required String title,
    required String body,
    required String prefilledMessage,
    String? longText,
    String? tag,
  }) async {
    final stableId = id; // already derived by caller from contactId
    final zone = await AwesomeNotifications().getLocalTimeZoneIdentifier();

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: stableId,
        channelKey: _channelKey,
        title: title,
        body: (longText?.trim().isNotEmpty == true) ? longText!.trim() : body,
        summary: body,
        payload: {'contactId': contactId, 'text': prefilledMessage},
        category: NotificationCategory.Reminder,
        notificationLayout: NotificationLayout.BigText,
        groupKey: 'keepup_contact_$contactId',
      ),
      schedule: NotificationCalendar(
        year: when.year,
        month: when.month,
        day: when.day,
        hour: when.hour,
        minute: when.minute,
        second: when.second,
        millisecond: 0,
        timeZone: zone,
        allowWhileIdle: true,
        preciseAlarm: false, // set true if you need exact-alarm behavior
      ),
    );
  }

  // Navigate into Compose when user taps the notification.
  static Future<void> _onActionReceived(ReceivedAction action) async {
    final payload = action.payload ?? {};
    final contactId = payload['contactId'];
    final text = payload['text'];
    if (contactId != null) {
      rootNavigatorKey.currentState?.pushNamed(
        AppRoutes.compose,
        arguments: {
          'contactId': contactId,
          if (text != null) 'initialText': text,
        },
      );
    }
  }
}
