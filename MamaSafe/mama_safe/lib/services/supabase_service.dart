import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://ntyqznoigmjsymenundu.supabase.co'; 
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im50eXF6bm9pZ21qc3ltZW51bmR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwMTY2MDYsImV4cCI6MjA3NTU5MjYwNn0.oIDPZDy_4gaY05XfMpLiQCXJrKYL7RUHc450zBU__fk';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
  static RealtimeChannel subscribeToTable(
      String table, Function(PostgresChangePayload) callback) {
    return client
        .channel('public:$table')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: callback,
        )
        .subscribe();
  }
  static SupabaseClient get client => Supabase.instance.client;
}