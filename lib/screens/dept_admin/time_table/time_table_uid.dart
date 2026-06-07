import 'dart:math';

String generateTimeTableUid() {
  const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const digits = '0123456789';
  final random = Random();

  final chars = List<String>.generate(8, (index) {
    if (index.isEven) {
      return letters[random.nextInt(letters.length)];
    }
    return digits[random.nextInt(digits.length)];
  });

  return chars.join();
}
