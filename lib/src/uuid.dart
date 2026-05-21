import 'dart:math';

/// Pure Dart UUID v4 generator.
///
/// Generates a random UUID v4 string of the form
/// `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` using [Random.secure].
String generateUuidV4() {
  final rng = Random.secure();

  // Generate 16 random bytes.
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Set version bits: version 4 → top nibble of byte 6 = 0100
  bytes[6] = (bytes[6] & 0x0f) | 0x40;

  // Set variant bits: RFC 4122 variant → top two bits of byte 8 = 10
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  // Format as xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');

  final b = bytes.map(hex).toList();
  return '${b[0]}${b[1]}${b[2]}${b[3]}'
      '-${b[4]}${b[5]}'
      '-${b[6]}${b[7]}'
      '-${b[8]}${b[9]}'
      '-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
}
