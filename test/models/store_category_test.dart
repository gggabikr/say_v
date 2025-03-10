import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:say_v/models/store.dart';

void main() {
  group('Store Category Tests', () {
    test('stores.json의 모든 카테고리가 StoreCategory enum에 정의되어 있는지 확인', () async {
      // 테스트 데이터 파일 읽기
      final String jsonString =
          await File('test/test_data/stores.json').readAsString();
      final data = json.decode(jsonString);

      // 모든 스토어 데이터 순회
      for (var storeData in data['stores']) {
        final storeName = storeData['name'];
        final categories = storeData['category'] as List;

        try {
          // 각 카테고리 값이 유효한지 검사
          for (var category in categories) {
            expect(
              () => StoreCategory.values.firstWhere(
                (e) => e.value == category,
              ),
              returnsNormally,
              reason:
                  '$storeName의 카테고리 "$category"가 StoreCategory enum에 정의되어 있지 않습니다.',
            );
          }
        } catch (e) {
          fail('$storeName의 카테고리 처리 중 오류 발생: $e');
        }
      }
    });

    test('모든 StoreCategory enum 값이 올바른 형식을 가지고 있는지 확인', () {
      for (var category in StoreCategory.values) {
        // 카테고리 값이 소문자이고 언더스코어로 구분되어 있는지 확인
        expect(
          category.value,
          matches(r'^[a-z_]+$'),
          reason:
              '카테고리 ${category.name}의 value "${category.value}"가 올바른 형식이 아닙니다. (소문자와 언더스코어만 허용)',
        );
      }
    });
  });
}
