import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationUpdateEvent {
  final Position position;
  LocationUpdateEvent(this.position);
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _locationController = StreamController<LocationUpdateEvent>.broadcast();
  Stream<LocationUpdateEvent> get onLocationUpdate =>
      _locationController.stream;

  void updateLocation(Position position) {
    _locationController.add(LocationUpdateEvent(position));
  }

  void dispose() {
    _locationController.close();
  }
}
