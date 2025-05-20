import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:say_v/models/report.dart';
import 'package:say_v/pages/reported_reviews_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StoreManagementScreen extends StatefulWidget {
  final String storeId;

  const StoreManagementScreen({
    super.key,
    required this.storeId,
  });

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  bool _isLoading = false;
  final Map<String, dynamic> _pendingChanges = {};
  final Map<String, List<dynamic>> _pendingAdditions = {};
  final Map<String, List<dynamic>> _pendingDeletions = {};
  final Set<String> _modifiedSections = {};
  bool _hasUnsavedChanges = false;
  bool _isContactValid = true;
  String? _contactErrorText;
  List<String> selectedCategories = [];
  List<String> selectedCuisineTypes = [];
  bool is24Hours = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<String> ownedStores =
            List<String>.from(userSnapshot.data?['ownedStores'] ?? []);
        final bool isAdmin = userSnapshot.data?['role'] == 'admin';
        final bool isOwner = ownedStores.contains(widget.storeId);

        if (!isOwner && !isAdmin) {
          return const Scaffold(
            body: Center(
              child: Text('접근 권한이 없습니다.'),
            ),
          );
        }

        return PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvoked: (didPop) async {
            if (didPop) return;

            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('저장되지 않은 변경사항'),
                content: const Text('변경사항을 저장하지 않고 나가시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('취소'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop(true);
                      // 상태 초기화 후 화면 나가기
                      setState(() {
                        _pendingChanges.clear();
                        _pendingAdditions.clear();
                        _pendingDeletions.clear();
                        _modifiedSections.clear();
                        _hasUnsavedChanges = false;
                      });
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('나가기'),
                  ),
                ],
              ),
            );
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('스토어 관리'),
              actions: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('reports')
                      .where('storeId', isEqualTo: widget.storeId)
                      .where('status', isEqualTo: ReportStatus.pending.name)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final reportCount = snapshot.data?.docs.length ?? 0;

                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.report_problem_outlined),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportedReviewsPage(
                                  storeId: widget.storeId,
                                ),
                              ),
                            );
                          },
                        ),
                        if (reportCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                reportCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (_hasUnsavedChanges) ...[
                  TextButton(
                    onPressed: _discardChanges,
                    child: const Text(
                      '변경취소',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAllChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '저장하기',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                ],
              ],
            ),
            body: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('stores')
                  .doc(widget.storeId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final storeData = snapshot.data!.data() as Map<String, dynamic>;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicInfoSection(storeData),
                      const SizedBox(height: 24),
                      _buildCategoriesSection(storeData),
                      const SizedBox(height: 24),
                      _buildCuisineTypesSection(storeData),
                      const SizedBox(height: 24),
                      _buildBusinessHoursSection(storeData),
                      const SizedBox(height: 24),
                      _buildHappyHoursSection(storeData),
                      const SizedBox(height: 24),
                      _buildMenuSection(storeData),
                      const SizedBox(height: 24),
                      _buildLocationSection(storeData),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBasicInfoSection(Map<String, dynamic> storeData) {
    final String currentContact = storeData['contactNumber'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('기본 정보', 'basic_info'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController..text = storeData['name'] ?? '',
              decoration: const InputDecoration(labelText: '스토어 이름'),
              enabled: false, // 이름은 수정 불가
            ),
            const SizedBox(height: 8),
            if (currentContact.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '현재 연락처: $currentContact',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            TextFormField(
              controller: _contactNumberController,
              decoration: InputDecoration(
                labelText: '연락처',
                hintText: '10자리 숫자만 입력해 주세요',
                errorText: _contactErrorText,
                errorStyle: const TextStyle(color: Colors.red),
                enabledBorder: _isContactValid
                    ? null
                    : const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                focusedBorder: _isContactValid
                    ? null
                    : const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                // 전화번호 형식 검증
                final cleanNumber = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (cleanNumber != value) {
                  _contactNumberController.text = cleanNumber;
                  _contactNumberController.selection =
                      TextSelection.fromPosition(
                    TextPosition(offset: cleanNumber.length),
                  );
                }

                setState(() {
                  if (value.isEmpty) {
                    _isContactValid = true;
                    _contactErrorText = null;
                  } else {
                    final isValid = RegExp(r'^\d{10}$').hasMatch(cleanNumber);
                    _isContactValid = isValid;
                    _contactErrorText = isValid ? null : '유효한 연락처를 입력해주세요';
                  }
                });

                if (value != currentContact) {
                  _updateStore({'contactNumber': cleanNumber}, 'basic_info');
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('24시간 영업'),
              value: storeData['is24Hours'] ?? false,
              onChanged: (bool value) {
                setState(() => is24Hours = value);
                _updateStore({'is24Hours': value}, 'basic_info');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(Map<String, dynamic> storeData) {
    // 현재 저장된 카테고리와 pending 변경사항을 모두 고려
    List<String> currentCategories =
        List<String>.from(storeData['category'] ?? []);

    // pending changes가 있다면 반영
    if (_pendingChanges.containsKey('category')) {
      currentCategories = List<String>.from(_pendingChanges['category'] ?? []);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Category', 'category'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _buildCategoryChip(
                    'Happy Hour', 'happy_hour', currentCategories),
                _buildCategoryChip(
                    'All You Can Eat', 'all_you_can_eat', currentCategories),
                _buildCategoryChip(
                    'Special Events', 'special_events', currentCategories),
                _buildCategoryChip('Deals & Discounts', 'deals_and_discounts',
                    currentCategories),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
      String label, String value, List<String> selectedCategories) {
    final bool isSelected = selectedCategories.contains(value);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        List<String> newCategories = List.from(selectedCategories);
        if (selected) {
          newCategories.add(value);
        } else {
          newCategories.remove(value);
        }
        setState(() {
          _pendingChanges['category'] = newCategories;
          _hasUnsavedChanges = true;
          _modifiedSections.add('category');
        });
      },
    );
  }

  Widget _buildCuisineTypesSection(Map<String, dynamic> storeData) {
    final List<String> cuisineTypes =
        (storeData['cuisineTypes'] as List?)?.cast<String>() ?? [];
    final pendingTypes = _pendingAdditions['cuisineType'] ?? [];
    final deletedTypes = _pendingDeletions['cuisineType'] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Cuisine Type', 'cuisineType'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddCuisineTypeDialog(cuisineTypes),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // 기존 타입 (삭제 예정 포함)
                ...cuisineTypes.map((type) {
                  final isDeleted = deletedTypes.contains(type);
                  return Chip(
                    backgroundColor: isDeleted ? Colors.grey[200] : null,
                    label: Text(
                      type,
                      style: TextStyle(
                        color: isDeleted ? Colors.grey[700] : null,
                        decoration:
                            isDeleted ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.grey[400],
                      ),
                    ),
                    deleteIcon: isDeleted
                        ? const Icon(Icons.restore, size: 20)
                        : const Icon(Icons.close, size: 20),
                    onDeleted: () {
                      if (isDeleted) {
                        setState(() {
                          _pendingDeletions['cuisineType']?.remove(type);
                          if (_pendingDeletions['cuisineType']?.isEmpty ??
                              false) {
                            _pendingDeletions.remove('cuisineType');
                          }
                          _hasUnsavedChanges = _pendingAdditions.isNotEmpty ||
                              _pendingDeletions.isNotEmpty ||
                              _pendingChanges.isNotEmpty;
                          if (!_hasUnsavedChanges) {
                            _modifiedSections.remove('cuisineType');
                          }
                        });
                      } else {
                        _markForDeletion(type, 'cuisineType');
                      }
                    },
                  );
                }),
                // 새로 추가된 타입
                ...pendingTypes.map((type) => Chip(
                      backgroundColor: Colors.grey[300],
                      label: Text(
                        type,
                        style: TextStyle(
                          color: Colors.grey[800],
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 20),
                      onDeleted: () {
                        setState(() {
                          _pendingAdditions['cuisineType']?.remove(type);
                          if (_pendingAdditions['cuisineType']?.isEmpty ??
                              false) {
                            _pendingAdditions.remove('cuisineType');
                          }
                          _hasUnsavedChanges = _pendingAdditions.isNotEmpty ||
                              _pendingDeletions.isNotEmpty ||
                              _pendingChanges.isNotEmpty;
                          if (!_hasUnsavedChanges) {
                            _modifiedSections.remove('cuisineType');
                          }
                        });
                      },
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHoursSection(Map<String, dynamic> storeData) {
    final List<dynamic> hours = List.from(storeData['businessHours'] ?? []);
    final pendingHours = _pendingAdditions['businessHours'] ?? [];
    final deletedHours = _pendingDeletions['businessHours'] ?? [];
    final bool is24Hours = storeData['is24Hours'] ?? false;

    if (is24Hours) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('영업 시간',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('24시간 영업중'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('영업 시간', 'businessHours'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showBusinessHoursDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: hours.length + pendingHours.length,
              itemBuilder: (context, index) {
                if (index < hours.length) {
                  final hour = hours[index];
                  // 각 항목의 고유 식별자로 daysOfWeek를 문자열로 변환하여 사용
                  final String hourId = (hour['daysOfWeek'] as List).join(',');
                  final isDeleted = deletedHours.any((deletedHour) =>
                      (deletedHour['daysOfWeek'] as List).join(',') == hourId);
                  final List<String> days =
                      List<String>.from(hour['daysOfWeek']);

                  return _buildListItemWithPendingChanges(
                    item: hour,
                    type: 'businessHours',
                    isPending: false,
                    isDeleted: isDeleted,
                    title: days.join(', '),
                    subtitle:
                        '${hour['openHour'].toString().padLeft(2, '0')}:${hour['openMinute'].toString().padLeft(2, '0')} - '
                        '${hour['closeHour'].toString().padLeft(2, '0')}:${hour['closeMinute'].toString().padLeft(2, '0')}',
                    onEdit: () => _showBusinessHoursDialog(existingHours: hour),
                    onDelete: () => _markForDeletion(hour, 'businessHours'),
                    onRestore: () => _restoreItem(hour, 'businessHours'),
                  );
                } else {
                  final pendingHour = pendingHours[index - hours.length];
                  final List<String> days =
                      List<String>.from(pendingHour['daysOfWeek']);

                  return _buildListItemWithPendingChanges(
                    item: pendingHour,
                    type: 'businessHours',
                    isPending: true,
                    isDeleted: false,
                    title: days.join(', '),
                    subtitle:
                        '${pendingHour['openHour'].toString().padLeft(2, '0')}:${pendingHour['openMinute'].toString().padLeft(2, '0')} - '
                        '${pendingHour['closeHour'].toString().padLeft(2, '0')}:${pendingHour['closeMinute'].toString().padLeft(2, '0')}',
                    onEdit: () =>
                        _showBusinessHoursDialog(existingHours: pendingHour),
                    onDelete: () {
                      setState(() {
                        _pendingAdditions['businessHours']?.remove(pendingHour);
                        if (_pendingAdditions['businessHours']?.isEmpty ??
                            false) {
                          _pendingAdditions.remove('businessHours');
                        }
                        _hasUnsavedChanges = _pendingAdditions.isNotEmpty ||
                            _pendingDeletions.isNotEmpty ||
                            _pendingChanges.isNotEmpty;
                        if (!_hasUnsavedChanges) {
                          _modifiedSections.remove('businessHours');
                        }
                      });
                    },
                    onRestore: () {}, // 사용되지 않음
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHappyHoursSection(Map<String, dynamic> storeData) {
    final List<dynamic> hours = List.from(storeData['happyHours'] ?? []);
    final pendingHours = _pendingAdditions['happyHours'] ?? [];
    final deletedHours = _pendingDeletions['happyHours'] ?? [];

    // 현재 선택된 카테고리 확인
    List<String> currentCategories =
        List<String>.from(storeData['category'] ?? []);
    if (_pendingChanges.containsKey('category')) {
      currentCategories = List<String>.from(_pendingChanges['category'] ?? []);
    }
    final bool isHappyHourEnabled = currentCategories.contains('happy_hour');

    return Stack(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('해피아워', 'happyHours'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: isHappyHourEnabled
                          ? () => _showHappyHourDialog()
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: hours.length + pendingHours.length,
                  itemBuilder: (context, index) {
                    if (index < hours.length) {
                      final hour = hours[index];
                      final String hourId =
                          (hour['daysOfWeek'] as List).join(',');
                      final isDeleted = deletedHours.any((deletedHour) =>
                          (deletedHour['daysOfWeek'] as List).join(',') ==
                          hourId);
                      final List<String> days =
                          List<String>.from(hour['daysOfWeek']);

                      return _buildListItemWithPendingChanges(
                        item: hour,
                        type: 'happyHours',
                        isPending: false,
                        isDeleted: isDeleted,
                        title: days.join(', '),
                        subtitle:
                            '${hour['startHour'].toString().padLeft(2, '0')}:${hour['startMinute'].toString().padLeft(2, '0')} - '
                            '${hour['endHour'].toString().padLeft(2, '0')}:${hour['endMinute'].toString().padLeft(2, '0')}',
                        onEdit: isHappyHourEnabled
                            ? () => _showHappyHourDialog(existingHours: hour)
                            : null,
                        onDelete: isHappyHourEnabled
                            ? () => _markForDeletion(hour, 'happyHours')
                            : null,
                        onRestore: isHappyHourEnabled
                            ? () => _restoreItem(hour, 'happyHours')
                            : null,
                      );
                    } else {
                      final pendingHour = pendingHours[index - hours.length];
                      final List<String> days =
                          List<String>.from(pendingHour['daysOfWeek']);

                      return _buildListItemWithPendingChanges(
                        item: pendingHour,
                        type: 'happyHours',
                        isPending: true,
                        isDeleted: false,
                        title: days.join(', '),
                        subtitle:
                            '${pendingHour['startHour'].toString().padLeft(2, '0')}:${pendingHour['startMinute'].toString().padLeft(2, '0')} - '
                            '${pendingHour['endHour'].toString().padLeft(2, '0')}:${pendingHour['endMinute'].toString().padLeft(2, '0')}',
                        onEdit: () =>
                            _showHappyHourDialog(existingHours: pendingHour),
                        onDelete: () {
                          setState(() {
                            _pendingAdditions['happyHours']
                                ?.remove(pendingHour);
                            if (_pendingAdditions['happyHours']?.isEmpty ??
                                false) {
                              _pendingAdditions.remove('happyHours');
                            }
                            _hasUnsavedChanges = _pendingAdditions.isNotEmpty ||
                                _pendingDeletions.isNotEmpty ||
                                _pendingChanges.isNotEmpty;
                            if (!_hasUnsavedChanges) {
                              _modifiedSections.remove('happyHours');
                            }
                          });
                        },
                        onRestore: () {}, // 사용되지 않음
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        if (!isHappyHourEnabled)
          Positioned.fill(
            child: Container(
              color: Colors.grey.withOpacity(0.5),
              child: const Center(
                child: Text(
                  '해피아워를 활성화하려면\n카테고리에서 Happy Hour를 선택하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuSection(Map<String, dynamic> storeData) {
    final List<dynamic> menus = List.from(storeData['menus'] ?? []);
    final pendingMenus = _pendingAdditions['menu'] ?? [];
    final deletedMenus = _pendingDeletions['menu'] ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('메뉴', 'menu'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showMenuItemDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: menus.length + pendingMenus.length,
              itemBuilder: (context, index) {
                if (index < menus.length) {
                  final menu = menus[index];
                  final isDeleted = deletedMenus.any(
                      (deletedMenu) => deletedMenu['itemId'] == menu['itemId']);

                  return _buildListItemWithPendingChanges(
                    item: menu,
                    type: 'menu',
                    isPending: false,
                    isDeleted: isDeleted,
                    title: menu['name'] ?? '',
                    subtitle: '\$${menu['price']} - ${menu['type']}',
                    onEdit: () => _showMenuItemDialog(existingMenu: menu),
                    onDelete: () => _markForDeletion(menu, 'menu'),
                    onRestore: () => _restoreItem(menu, 'menu'),
                  );
                } else {
                  final pendingMenu = pendingMenus[index - menus.length];

                  return _buildListItemWithPendingChanges(
                    item: pendingMenu,
                    type: 'menu',
                    isPending: true,
                    isDeleted: false,
                    title: pendingMenu['name'] ?? '',
                    subtitle:
                        '\$${pendingMenu['price']} - ${pendingMenu['type']}',
                    onEdit: () =>
                        _showMenuItemDialog(existingMenu: pendingMenu),
                    onDelete: () {
                      setState(() {
                        _pendingAdditions['menu']?.remove(pendingMenu);
                        if (_pendingAdditions['menu']?.isEmpty ?? false) {
                          _pendingAdditions.remove('menu');
                        }
                        _hasUnsavedChanges = _pendingAdditions.isNotEmpty ||
                            _pendingDeletions.isNotEmpty ||
                            _pendingChanges.isNotEmpty;
                        if (!_hasUnsavedChanges) {
                          _modifiedSections.remove('menu');
                        }
                      });
                    },
                    onRestore: () {}, // 사용되지 않음
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(Map<String, dynamic> storeData) {
    final location = storeData['location'] as GeoPoint;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '위치 정보',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('위도: ${location.latitude}'),
              subtitle: Text('경도: ${location.longitude}'),
              trailing: IconButton(
                icon: const Icon(Icons.edit_location),
                onPressed: () => _showLocationDialog(location),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String sectionKey) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_modifiedSections.contains(sectionKey))
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.edit,
              size: 16,
              color: Colors.blue,
            ),
          ),
      ],
    );
  }

  Future<void> _saveAllChanges() async {
    if (!_hasUnsavedChanges) return;

    // 연락처 유효성 검사
    if (_pendingChanges.containsKey('contactNumber')) {
      final contactNumber = _pendingChanges['contactNumber'] as String;
      if (!RegExp(r'^\d{10}$').hasMatch(contactNumber)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장할 수 없습니다. 유효한 연락처를 입력해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final storeRef =
          FirebaseFirestore.instance.collection('stores').doc(widget.storeId);

      final storeSnapshot = await storeRef.get();
      final storeData = storeSnapshot.data() ?? {};

      // 각 섹션별 데이터 업데이트
      for (String section in _modifiedSections) {
        if (section == 'menu') {
          List<dynamic> currentMenus = List.from(storeData['menus'] ?? []);

          // 삭제 예정 항목 제거
          currentMenus.removeWhere((menu) =>
              _pendingDeletions['menu']?.any(
                  (deletedMenu) => deletedMenu['itemId'] == menu['itemId']) ??
              false);

          // 새로운 항목 추가
          if (_pendingAdditions['menu'] != null) {
            currentMenus.addAll(_pendingAdditions['menu']!);
          }

          _pendingChanges['menus'] = currentMenus;
        }
        // Cuisine Type 처리 추가
        else if (section == 'cuisineType') {
          List<String> currentTypes =
              List<String>.from(storeData['cuisineTypes'] ?? []);

          // 삭제 예정 항목 제거
          currentTypes.removeWhere((type) =>
              _pendingDeletions['cuisineType']?.contains(type) ?? false);

          // 새로운 항목 추가
          if (_pendingAdditions['cuisineType'] != null) {
            currentTypes
                .addAll(_pendingAdditions['cuisineType']!.cast<String>());
          }

          _pendingChanges['cuisineTypes'] = currentTypes;
        }
        // 다른 섹션들에 대한 처리도 비슷하게 추가...
        else if (section == 'businessHours') {
          List<dynamic> currentHours =
              List.from(storeData['businessHours'] ?? []);
          // 삭제 예정 항목 제거
          currentHours.removeWhere((hour) =>
              _pendingDeletions['businessHours']?.any((deletedHour) =>
                  (deletedHour['daysOfWeek'] as List).join(',') ==
                  (hour['daysOfWeek'] as List).join(',')) ??
              false);
          // 새로운 항목 추가
          if (_pendingAdditions['businessHours'] != null) {
            currentHours.addAll(_pendingAdditions['businessHours']!);
          }
          _pendingChanges['businessHours'] = currentHours;
        } else if (section == 'happyHours') {
          List<dynamic> currentHours = List.from(storeData['happyHours'] ?? []);
          // 삭제 예정 항목 제거
          currentHours.removeWhere((hour) =>
              _pendingDeletions['happyHours']?.any((deletedHour) =>
                  (deletedHour['daysOfWeek'] as List).join(',') ==
                  (hour['daysOfWeek'] as List).join(',')) ??
              false);
          // 새로운 항목 추가
          if (_pendingAdditions['happyHours'] != null) {
            currentHours.addAll(_pendingAdditions['happyHours']!);
          }
          _pendingChanges['happyHours'] = currentHours;
        }
      }

      // 모든 변경사항 한번에 저장
      await storeRef.update(_pendingChanges);

      // 저장 성공 후 상태 초기화
      setState(() {
        _pendingChanges.clear();
        _pendingAdditions.clear();
        _pendingDeletions.clear();
        _modifiedSections.clear();
        _hasUnsavedChanges = false;
        _isLoading = false;
        _isContactValid = true;
        _contactErrorText = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('모든 변경사항이 저장되었습니다')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _updateStore(Map<String, dynamic> data, String sectionKey) {
    setState(() {
      _pendingChanges.addAll(data);
      _modifiedSections.add(sectionKey);
      _hasUnsavedChanges = true;
    });
  }

  void _showAddCuisineTypeDialog(List<String> currentTypes) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('음식 종류 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '음식 종류',
            hintText: '예: Korean, Asian, BBQ...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  if (!_pendingAdditions.containsKey('cuisineType')) {
                    _pendingAdditions['cuisineType'] = [];
                  }
                  _pendingAdditions['cuisineType']!.add(controller.text.trim());
                  _hasUnsavedChanges = true;
                  _modifiedSections.add('cuisineType');
                });
                Navigator.pop(context);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _showBusinessHoursDialog({Map<String, dynamic>? existingHours}) {
    final List<String> daysOfWeek = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN'
    ];
    List<String> selectedDays =
        List<String>.from(existingHours?['daysOfWeek'] ?? []);
    TimeOfDay openTime = existingHours != null
        ? TimeOfDay(
            hour: existingHours['openHour'],
            minute: existingHours['openMinute'])
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay closeTime = existingHours != null
        ? TimeOfDay(
            hour: existingHours['closeHour'],
            minute: existingHours['closeMinute'])
        : const TimeOfDay(hour: 22, minute: 0);
    bool isNextDay = existingHours?['isNextDay'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingHours == null ? '영업 시간 추가' : '영업 시간 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('영업일 선택'),
                Wrap(
                  spacing: 8,
                  children: daysOfWeek
                      .map((day) => FilterChip(
                            label: Text(day),
                            selected: selectedDays.contains(day),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(day);
                                } else {
                                  selectedDays.remove(day);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
                ListTile(
                  title: const Text('오픈 시간'),
                  trailing: Text(openTime.format(context)),
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: openTime,
                    );
                    if (time != null) {
                      setDialogState(() => openTime = time);
                    }
                  },
                ),
                ListTile(
                  title: const Text('마감 시간'),
                  trailing: Text(closeTime.format(context)),
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: closeTime,
                    );
                    if (time != null) {
                      setDialogState(() => closeTime = time);
                    }
                  },
                ),
                CheckboxListTile(
                  title: const Text('다음날까지'),
                  value: isNextDay,
                  onChanged: (value) {
                    setDialogState(() => isNextDay = value ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDays.isNotEmpty) {
                  final Map<String, dynamic> hours = {
                    'daysOfWeek': selectedDays,
                    'openHour': openTime.hour,
                    'openMinute': openTime.minute,
                    'closeHour': closeTime.hour,
                    'closeMinute': closeTime.minute,
                    'isNextDay': isNextDay,
                  };

                  if (existingHours != null) {
                    // 기존 항목 수정
                    _updateStore({'businessHours': hours}, 'businessHours');
                  } else {
                    // 새 항목 추가
                    // 상위 위젯의 setState 사용
                    setState(() {
                      if (!_pendingAdditions.containsKey('businessHours')) {
                        _pendingAdditions['businessHours'] = [];
                      }
                      _pendingAdditions['businessHours']!.add(hours);
                      _hasUnsavedChanges = true;
                      _modifiedSections.add('businessHours');
                    });
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(existingHours == null ? '추가' : '수정'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHappyHourDialog({Map<String, dynamic>? existingHours}) {
    final List<String> daysOfWeek = [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN'
    ];
    List<String> selectedDays =
        List<String>.from(existingHours?['daysOfWeek'] ?? []);
    TimeOfDay startTime = existingHours != null
        ? TimeOfDay(
            hour: existingHours['startHour'],
            minute: existingHours['startMinute'])
        : const TimeOfDay(hour: 15, minute: 0);
    TimeOfDay endTime = existingHours != null
        ? TimeOfDay(
            hour: existingHours['endHour'], minute: existingHours['endMinute'])
        : const TimeOfDay(hour: 18, minute: 0);
    bool isNextDay = existingHours?['isNextDay'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingHours == null ? '해피아워 추가' : '해피아워 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('해피아워 요일 선택'),
                Wrap(
                  spacing: 8,
                  children: daysOfWeek
                      .map((day) => FilterChip(
                            label: Text(day),
                            selected: selectedDays.contains(day),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(day);
                                } else {
                                  selectedDays.remove(day);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
                ListTile(
                  title: const Text('시작 시간'),
                  trailing: Text(startTime.format(context)),
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (time != null) {
                      setDialogState(() => startTime = time);
                    }
                  },
                ),
                ListTile(
                  title: const Text('종료 시간'),
                  trailing: Text(endTime.format(context)),
                  onTap: () async {
                    final TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                    );
                    if (time != null) {
                      setDialogState(() => endTime = time);
                    }
                  },
                ),
                CheckboxListTile(
                  title: const Text('다음날까지'),
                  value: isNextDay,
                  onChanged: (value) {
                    setDialogState(() => isNextDay = value ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDays.isNotEmpty) {
                  final Map<String, dynamic> hours = {
                    'daysOfWeek': selectedDays,
                    'startHour': startTime.hour,
                    'startMinute': startTime.minute,
                    'endHour': endTime.hour,
                    'endMinute': endTime.minute,
                    'isNextDay': isNextDay,
                  };

                  if (existingHours != null) {
                    // 기존 항목 수정
                    _updateStore({'happyHours': hours}, 'happyHours');
                  } else {
                    // 새 항목 추가
                    setState(() {
                      if (!_pendingAdditions.containsKey('happyHours')) {
                        _pendingAdditions['happyHours'] = [];
                      }
                      _pendingAdditions['happyHours']!.add(hours);
                      _hasUnsavedChanges = true;
                      _modifiedSections.add('happyHours');
                    });
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(existingHours == null ? '추가' : '수정'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenuItemDialog({Map<String, dynamic>? existingMenu}) {
    final nameController =
        TextEditingController(text: existingMenu?['name'] ?? '');
    final priceController = TextEditingController(
      text: existingMenu?['price']?.toString() ?? '',
    );
    String selectedType = existingMenu?['type'] ?? 'food';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existingMenu == null ? '메뉴 추가' : '메뉴 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '메뉴 이름'),
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: '가격'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: '메뉴 종류'),
                  items: const [
                    DropdownMenuItem(value: 'food', child: Text('음식')),
                    DropdownMenuItem(value: 'drink', child: Text('음료')),
                    DropdownMenuItem(value: 'alcohol', child: Text('주류')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedType = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    priceController.text.isNotEmpty) {
                  final menuItem = {
                    'itemId': existingMenu?['itemId'] ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': nameController.text,
                    'price': double.parse(priceController.text),
                    'type': selectedType,
                  };

                  if (existingMenu == null) {
                    // 새로운 메뉴 추가
                    _addPendingItem(menuItem, 'menu');
                  } else {
                    // 기존 메뉴 수정
                    _updateStore({'menus': menuItem}, 'menu');
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(existingMenu == null ? '추가' : '수정'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog(GeoPoint location) {
    final latitudeController = TextEditingController(
      text: location.latitude.toString(),
    );
    final longitudeController = TextEditingController(
      text: location.longitude.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 정보 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latitudeController,
              decoration: const InputDecoration(labelText: '위도'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: longitudeController,
              decoration: const InputDecoration(labelText: '경도'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (latitudeController.text.isNotEmpty &&
                  longitudeController.text.isNotEmpty) {
                _updateStore({
                  'location': GeoPoint(
                    double.parse(latitudeController.text),
                    double.parse(longitudeController.text),
                  ),
                }, 'location');
                Navigator.pop(context);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _discardChanges() async {
    final bool confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('변경사항 취소'),
            content: const Text('모든 변경사항이 취소됩니다. 계속하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('아니오'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('예'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        _pendingChanges.clear();
        _pendingAdditions.clear();
        _pendingDeletions.clear();
        _modifiedSections.clear();
        _hasUnsavedChanges = false;
      });
    }
  }

  Widget _buildListItemWithPendingChanges({
    required dynamic item,
    required String type,
    required bool isPending,
    required bool isDeleted,
    required String title,
    required String? subtitle,
    required VoidCallback? onEdit,
    required VoidCallback? onDelete,
    required VoidCallback? onRestore,
  }) {
    return Container(
      decoration: isPending
          ? BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            color: isPending ? Colors.grey[800] : null,
            decoration: isDeleted ? TextDecoration.lineThrough : null,
            decorationColor: Colors.grey[400],
            decorationThickness: 2,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: isPending ? Colors.grey[700] : Colors.grey[700],
                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.grey[400],
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDeleted) ...[
              IconButton(
                icon: Icon(Icons.edit,
                    color: isPending ? Colors.grey[700] : null),
                onPressed: onEdit,
              ),
              IconButton(
                icon: Icon(Icons.delete,
                    color: isPending ? Colors.grey[700] : null),
                onPressed: onDelete,
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.restore),
                onPressed: onRestore,
              ),
          ],
        ),
      ),
    );
  }

  void _markForDeletion(dynamic item, String type) {
    setState(() {
      if (!_pendingDeletions.containsKey(type)) {
        _pendingDeletions[type] = [];
      }

      if (!_pendingDeletions[type]!.contains(item)) {
        _pendingDeletions[type]!.add(item);
      }

      _hasUnsavedChanges = true;
      _modifiedSections.add(type);
    });
  }

  void _restoreItem(dynamic item, String type) {
    setState(() {
      _pendingDeletions[type]?.removeWhere(
          (deletedItem) => deletedItem['itemId'] == item['itemId']);

      if (_pendingDeletions[type]?.isEmpty ?? false) {
        _pendingDeletions.remove(type);
      }

      _hasUnsavedChanges =
          _pendingDeletions.isNotEmpty || _pendingAdditions.isNotEmpty;
      if (!_hasUnsavedChanges) {
        _modifiedSections.remove(type);
      }
    });
  }

  void _addPendingItem(dynamic item, String type) {
    setState(() {
      if (!_pendingAdditions.containsKey(type)) {
        _pendingAdditions[type] = [];
      }
      _pendingAdditions[type]!.add(item);
      _hasUnsavedChanges = true;
      _modifiedSections.add(type);
    });
  }

  void _showEditDialog(dynamic item, String type) {
    // Implementation of _showEditDialog method
  }
}
