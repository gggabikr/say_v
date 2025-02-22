import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() {
    // 테스트 바인딩 초기화 시 assets 디렉토리 설정
    TestWidgetsFlutterBinding.ensureInitialized();

    // Assets 디렉토리 등록
    final directory = Directory.current;
    final assetDirectory = '${directory.path}/assets/data';

    // Uri로 변환하여 전달
    goldenFileComparator =
        LocalFileComparator(Uri.parse('file://$assetDirectory'));
  });

  await testMain();
}
