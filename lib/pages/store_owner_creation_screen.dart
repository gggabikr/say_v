import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:say_v/widgets/keep_alive_wrapper.dart';
import '../widgets/store_checkbox_tile.dart';
import 'package:flutter/services.dart';

class StoreOwnerCreationScreen extends StatefulWidget {
  const StoreOwnerCreationScreen({super.key});

  @override
  State<StoreOwnerCreationScreen> createState() =>
      _StoreOwnerCreationScreenState();
}

class _StoreOwnerCreationScreenState extends State<StoreOwnerCreationScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _selectedStores = [];
  final _storeIdController = TextEditingController();
  bool _isLoading = false;
  bool _showOnlyAvailable = true;
  final int _limit = 20;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final List<QueryDocumentSnapshot> _stores = [];
  final _loadMoreButtonKey = GlobalKey();
  bool _isLoadingMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _scrollController.dispose();
    _storeIdController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _getStoresStream() {
    Query query = FirebaseFirestore.instance.collection('stores');
    if (_showOnlyAvailable) {
      query = query.where('ownerId', isNull: true);
    }
    return query.orderBy('name').limit(_limit).snapshots();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _lastDocument == null || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      Query query = FirebaseFirestore.instance.collection('stores');

      if (_showOnlyAvailable) {
        query = query.where('ownerId', isNull: true);
      }

      query = query
          .orderBy('name')
          .startAfterDocument(_lastDocument!)
          .limit(_limit);

      final snapshot = await query.get();

      if (snapshot.docs.length < _limit) {
        _hasMore = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _stores.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.last;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      print('오류 발생: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 스토어 오너 계정 생성'),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '이메일'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '이메일을 입력해주세요';
                    }
                    if (!value.contains('@')) {
                      return '올바른 이메일 형식이 아닙니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmEmailController,
                  decoration: const InputDecoration(
                    labelText: '이메일 확인',
                    hintText: '이메일 주소를 다시 입력하세요',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '이메일을 다시 입력해주세요';
                    }
                    if (value != _emailController.text) {
                      return '이메일이 일치하지 않습니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    hintText: '비밀번호를 입력하세요',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요';
                    }
                    if (value.length < 6) {
                      return '비밀번호는 최소 6자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호 확인',
                    hintText: '비밀번호를 다시 입력하세요',
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 다시 입력해주세요';
                    }
                    if (value != _passwordController.text) {
                      return '비밀번호가 일치하지 않습니다';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    hintText: '스토어 오너의 이름을 입력하세요',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  '관리할 스토어 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showCreateStoreDialog,
                  icon: const Icon(Icons.add_business),
                  label: const Text('새 스토어 생성'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _storeIdController,
                        decoration: const InputDecoration(
                          hintText: '직접 Store ID 입력',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final storeId = _storeIdController.text.trim();
                        if (storeId.isEmpty) return;

                        if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(storeId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Store ID는 영문자와 숫자만 사용 가능합니다'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        try {
                          final storeDoc = await FirebaseFirestore.instance
                              .collection('stores')
                              .doc(storeId)
                              .get();

                          if (!storeDoc.exists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('일치하는 스토어가 없습니다'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            if (!_selectedStores.contains(storeId)) {
                              _selectedStores.insert(0, storeId);
                            }
                          });

                          _storeIdController.clear();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('스토어 정보를 불러오는데 실패했습니다'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: const Text('제출'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('빈 스토어만 보기'),
                    Switch(
                      value: _showOnlyAvailable,
                      onChanged: (value) {
                        setState(() {
                          _showOnlyAvailable = value;
                          _lastDocument = null;
                          _hasMore = true;
                          _stores.clear();
                        });
                      },
                    ),
                  ],
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _getStoresStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text('스토어 목록을 불러오는데 실패했습니다.');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final stores = snapshot.data?.docs ?? [];
                    if (stores.isEmpty) {
                      return const Text('관리할 수 있는 스토어가 없습니다.');
                    }

                    if (_lastDocument == null && stores.isNotEmpty) {
                      _lastDocument = stores.last;
                    }

                    return Column(
                      children: [
                        ...stores.map((store) {
                          final storeData =
                              store.data() as Map<String, dynamic>;
                          final storeId = store.id;
                          final storeName = storeData['name'] as String;

                          return StoreCheckboxTile(
                            storeId: storeId,
                            storeName: storeName,
                            selectedStores: _selectedStores,
                          );
                        }).toList(),
                        if (_hasMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ElevatedButton(
                              key: _loadMoreButtonKey,
                              onPressed: _isLoadingMore ? null : _loadMore,
                              child: _isLoadingMore
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('더 보기'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createStoreOwnerAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 3,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              '스토어 오너 계정 생성',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createStoreOwnerAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 하나의 스토어를 선택해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createStoreOwnerAccount');
      await callable.call({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'displayName': _displayNameController.text.trim(),
        'storeIds': _selectedStores,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('스토어 오너 계정이 생성되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showCreateStoreDialog() async {
    final nameController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 스토어 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '스토어 이름',
                hintText: '새로운 스토어의 이름을 입력하세요',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              try {
                // 새 스토어 생성
                final storeRef =
                    await FirebaseFirestore.instance.collection('stores').add({
                  'name': name,
                  'nameLower': name.toLowerCase(),
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'ownerId': null, // 계정 생성 시 설정될 예정
                  'menuCategories': [],
                  'ratings': {
                    'average': 0,
                    'total': 0,
                    'scores': [],
                  },
                  'location': const GeoPoint(0, 0), // 기본값
                  'is24Hours': false,
                  'businessHours': [],
                  'happyHours': [],
                  'menus': [],
                });

                if (mounted) {
                  // 생성된 스토어를 선택된 목록에 추가
                  setState(() {
                    _selectedStores.insert(0, storeRef.id);
                  });

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('새 스토어가 생성되었습니다'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('스토어 생성 실패: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }
}
