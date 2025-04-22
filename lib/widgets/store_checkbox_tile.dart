import 'package:flutter/material.dart';

class StoreCheckboxTile extends StatefulWidget {
  final String storeId;
  final String storeName;
  final List<String> selectedStores;

  const StoreCheckboxTile({
    Key? key,
    required this.storeId,
    required this.storeName,
    required this.selectedStores,
  }) : super(key: key);

  @override
  State<StoreCheckboxTile> createState() => _StoreCheckboxTileState();
}

class _StoreCheckboxTileState extends State<StoreCheckboxTile> {
  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(widget.storeName),
      subtitle: Text('ID: ${widget.storeId}'),
      value: widget.selectedStores.contains(widget.storeId),
      onChanged: (bool? value) {
        if (value == true) {
          widget.selectedStores.add(widget.storeId);
        } else {
          widget.selectedStores.remove(widget.storeId);
        }
        setState(() {});
      },
    );
  }
}
