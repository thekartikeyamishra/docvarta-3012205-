// lib/utils/encryption_util.dart
import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'dart:typed_data';

class EncryptionUtil {
  // AES-GCM encryption with 32-byte key (base64).
  static String encryptJson(Map<String, dynamic> json, String base64Key) {
    final key = Key.fromBase64(base64Key);
    final iv = IV.fromLength(12); // GCM recommended 12 bytes
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final plain = utf8.encode(jsonEncode(json));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);
    final combined = iv.bytes + encrypted.bytes;
    return base64.encode(combined);
  }

  static Map<String, dynamic> decryptToJson(String base64Combined, String base64Key) {
    final combined = base64.decode(base64Combined);
    final ivBytes = combined.sublist(0, 12);
    final cipherBytes = combined.sublist(12);
    final key = Key.fromBase64(base64Key);
    final iv = IV(Uint8List.fromList(ivBytes));
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final decrypted = encrypter.decryptBytes(Encrypted(cipherBytes), iv: iv);
    return jsonDecode(utf8.decode(decrypted));
  }
}
