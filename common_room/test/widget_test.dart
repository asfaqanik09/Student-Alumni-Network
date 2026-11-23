
import 'package:flutter_test/flutter_test.dart';
import 'package:common_room/main.dart';

void main() {
  testWidgets('Common Room app starts successfully',
          (WidgetTester tester) async {
        await tester.pumpWidget(const CommonRoomApp());

        expect(find.byType(CommonRoomApp), findsOneWidget);
      });
}
