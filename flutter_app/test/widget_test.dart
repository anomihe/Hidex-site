// Placeholder smoke test.
//
// The real app boots Supabase/Firebase/AdMob from `.env` in
// `main()`, which isn't available in the test environment, so this
// intentionally doesn't pump `BibleApp`. Replace with widget tests that
// construct individual screens (with mocked services) as those screens
// stabilize.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder', () {
    expect(1 + 1, 2);
  });
}
