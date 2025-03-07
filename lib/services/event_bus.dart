import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationUpdateEvent {
  final Position position;
  LocationUpdateEvent(this.position);
}

class AddressUpdateEvent {
  final Position position;
  final String address;
  AddressUpdateEvent(this.position, this.address);
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _locationController = StreamController<LocationUpdateEvent>.broadcast();
  final _addressController = StreamController<AddressUpdateEvent>.broadcast();

  Stream<LocationUpdateEvent> get onLocationUpdate =>
      _locationController.stream;
  Stream<AddressUpdateEvent> get onAddressUpdate => _addressController.stream;

  void updateLocation(Position position) {
    _locationController.add(LocationUpdateEvent(position));
  }

  void updateAddress(Position position, String address) {
    _addressController.add(AddressUpdateEvent(position, address));
  }

  void dispose() {
    _locationController.close();
    _addressController.close();
  }
}
