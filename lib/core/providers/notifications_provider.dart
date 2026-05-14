import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotifType { error, warning, info, success }

class AppNotification {
  AppNotification({
    required this.message,
    this.type = NotifType.error,
    this.action,
    this.actionLabel,
  }) : id = DateTime.now().microsecondsSinceEpoch;

  final int id;
  final String message;
  final NotifType type;
  final void Function()? action;
  final String? actionLabel;
}

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [];

  void show(AppNotification n) {
    state = [...state, n];
    // Auto-dismiss after 5s
    Future.delayed(const Duration(seconds: 5), () => dismiss(n.id));
  }

  void showError(String message, {void Function()? onRetry}) => show(
        AppNotification(
          message: message,
          type: NotifType.error,
          action: onRetry,
          actionLabel: 'Retry',
        ),
      );

  void showInfo(String message) => show(
        AppNotification(message: message, type: NotifType.info),
      );

  void dismiss(int id) {
    state = state.where((n) => n.id != id).toList();
  }

  void dismissAll() => state = [];
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(
        () => NotificationsNotifier());
