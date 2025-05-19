import 'package:flutter/foundation.dart';
import '../models/store.dart';

class StoreUpdateNotifier {
  static final StoreUpdateNotifier instance = StoreUpdateNotifier._internal();
  factory StoreUpdateNotifier() => instance;
  StoreUpdateNotifier._internal();

  final ValueNotifier<Store?> _storeUpdateNotifier =
      ValueNotifier<Store?>(null);

  void notifyStoreUpdate(Store store) {
    _storeUpdateNotifier.value = store;
  }

  ValueNotifier<Store?> get storeUpdateNotifier => _storeUpdateNotifier;
}
