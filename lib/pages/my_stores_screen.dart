import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:say_v/pages/store_management_screen.dart';

class MyStoresScreen extends StatelessWidget {
  const MyStoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 상점 관리'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.hasError) {
            return const Center(child: Text('오류가 발생했습니다'));
          }

          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final ownedStores = List<String>.from(userData['ownedStores'] ?? []);

          if (ownedStores.isEmpty) {
            return const Center(child: Text('관리 중인 상점이 없습니다'));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stores')
                .where(FieldPath.documentId, whereIn: ownedStores)
                .snapshots(),
            builder: (context, storesSnapshot) {
              if (storesSnapshot.hasError) {
                return const Center(child: Text('상점 정보를 불러오는데 실패했습니다'));
              }

              if (!storesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final stores = storesSnapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: stores.length,
                itemBuilder: (context, index) {
                  final store = stores[index].data() as Map<String, dynamic>;
                  final storeId = stores[index].id;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(
                        store['name'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('Store ID: $storeId'),
                          const SizedBox(height: 4),
                          Text(
                            '메뉴 ${(store['menus'] as List?)?.length ?? 0}개',
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  StoreManagementScreen(storeId: storeId),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
