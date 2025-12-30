// lib/config/agora_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AgoraConfig {
  // Private constructor
  AgoraConfig._();

  /// Agora App ID from environment variables
  static String get appId {
    final id = dotenv.env['AGORA_APP_ID'];
    if (id == null || id.isEmpty) {
      throw Exception('AGORA_APP_ID not found in .env file');
    }
    return id;
  }

  /// Check if Agora is properly configured
  static bool get isConfigured {
    try {
      final id = dotenv.env['AGORA_APP_ID'];
      return id != null && id.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get configuration error message
  static String get configError {
    if (!isConfigured) {
      return '''
Agora not configured properly.

Required in .env file:
AGORA_APP_ID=your_app_id_here

Steps to fix:
1. Create account at https://console.agora.io/
2. Create new project
3. Copy App ID
4. Add to .env file
''';
    }
    return '';
  }

  /// Print configuration status (for debugging)
  static void printConfig() {
    print('═══════════════════════════════════════');
    print('Agora Configuration');
    print('═══════════════════════════════════════');
    if (isConfigured) {
      print('Status: CONFIGURED');
      print('App ID: ${appId.substring(0, 8)}****');
    } else {
      print('Status: NOT CONFIGURED');
      print('Error: $configError');
    }
    print('═══════════════════════════════════════');
  }
}