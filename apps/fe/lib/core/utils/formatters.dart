import 'package:intl/intl.dart';

/// Formatting helpers for Vietnamese currency (VNĐ) and timestamps.
abstract final class AppFormatters {
  static final NumberFormat _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  /// Formats a numeric amount in VND (e.g. `1350000` -> `1.350.000 ₫`).
  static String formatVnd(num amount) {
    return _vndFormat.format(amount);
  }

  /// Formats a [DateTime] into a concise Vietnamese relative or calendar string.
  static String formatRelativeDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Mới đăng';
    }
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    }
    return DateFormat('dd/MM/yyyy').format(dateTime.toLocal());
  }

  /// Alias for [formatRelativeDate].
  static String formatRelativeTime(DateTime? dateTime) =>
      formatRelativeDate(dateTime);
}
