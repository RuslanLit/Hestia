
int _javaHashCode(String s) {
  int hash = 0;
  for (int i = 0; i < s.length; i++) {
    hash = (31 * hash + s.codeUnitAt(i)) & 0xFFFFFFFF;
  }
  return hash;
}

void main() {
  final testStrings = [
    "65237e556af8f",
    "9e86c5f4-a8c9-4555-994a-25e39e6f8627",
    "236efbc7-34b8-4a13-83e8-24b76c10fd4a",
    "abc",
    "hello world!",
    "",
  ];
  for (final s in testStrings) {
    print("String: '$s', hash: ${_javaHashCode(s)}, masked: ${_javaHashCode(s) & 0x7fffffff}");
  }
}
