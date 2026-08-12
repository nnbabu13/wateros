import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final SupabaseService _supabaseService;

  NotificationRepository(this._supabaseService);

  Future<List<NotificationModel>> getNotifications(
    String businessId, {
    String? userId,
    bool? unreadOnly,
  }) async {
    try {
      final filters = <String, dynamic>{
        'business_id': businessId,
      };

      if (userId != null) {
        filters['user_id'] = userId;
      }
      if (unreadOnly == true) {
        filters['is_read'] = false;
      }

      final data = await _supabaseService.fetchAll(
        table: 'notifications',
        filters: filters,
        orderBy: 'created_at',
        ascending: false,
      );

      return data.map((json) => NotificationModel.fromJson(json)).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch notifications',
        originalError: e,
      );
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _supabaseService.update(
        table: 'notifications',
        id: id,
        data: {
          'is_read': true,
        },
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to mark notification as read',
        originalError: e,
      );
    }
  }

  Future<void> markAllAsRead(String businessId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'notifications',
        filters: {
          'business_id': businessId,
          'is_read': false,
        },
      );

      for (final notification in data) {
        await _supabaseService.update(
          table: 'notifications',
          id: notification['id'],
          data: {
            'is_read': true,
          },
        );
      }
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to mark all notifications as read',
        originalError: e,
      );
    }
  }

  Future<NotificationModel> createNotification(Map<String, dynamic> data) async {
    try {
      final result = await _supabaseService.insert(
        table: 'notifications',
        data: data,
      );
      return NotificationModel.fromJson(result);
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to create notification',
        originalError: e,
      );
    }
  }

  Future<int> getUnreadCount(String businessId) async {
    try {
      final data = await _supabaseService.fetchAll(
        table: 'notifications',
        filters: {
          'business_id': businessId,
          'is_read': false,
        },
        select: 'id',
      );

      return data.length;
    } catch (e) {
      throw DatabaseException(
        message: 'Failed to fetch unread count',
        originalError: e,
      );
    }
  }
}
