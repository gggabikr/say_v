import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreOwnerCreationScreen extends StatefulWidget {
  const StoreOwnerCreationScreen({super.key});

  @override
  State<StoreOwnerCreationScreen> createState() =>
      _StoreOwnerCreationScreenState();
}

class _StoreOwnerCreationScreenState extends State<StoreOwnerCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final List<String> _selectedStores = [];
  bool _isLoading = false;

  // 스토어 목록을 가져오는 스트림
  final Stream<QuerySnapshot> _storesStream = FirebaseFirestore.instance
      .collection('stores')
      .where('ownerId', isNull: true) // 아직 오너가 없는 스토어만
      .snapshots();

  @override
  void dispose() {
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 스토어 오너 계정 생성'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  hintText: '스토어 오너의 이메일 주소를 입력하세요',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!value.contains('@')) {
                    return '유효한 이메일 주소를 입력해주세요';
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
                  hintText: '스토어 오너의 비밀번호를 입력하세요',
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
              StreamBuilder<QuerySnapshot>(
                stream: _storesStream,
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

                  return Column(
                    children: stores.map((store) {
                      final storeData = store.data() as Map<String, dynamic>;
                      final storeId = store.id;
                      final storeName = storeData['name'] as String;

                      return CheckboxListTile(
                        title: Text(storeName),
                        value: _selectedStores.contains(storeId),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedStores.add(storeId);
                            } else {
                              _selectedStores.remove(storeId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _createStoreOwnerAccount,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('스토어 오너 계정 생성'),
              ),
            ],
          ),
        ),
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
      final result = await callable.call({
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
}
