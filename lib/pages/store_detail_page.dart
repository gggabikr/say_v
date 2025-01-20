import 'package:flutter/material.dart';
import '../models/store.dart';

class StoreDetailPage extends StatefulWidget {
  final Store store;

  const StoreDetailPage({Key? key, required this.store}) : super(key: key);

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  String _selectedCategory = 'food';
  final List<String> _categories = [
    'food',
    'alcohol',
    'drink',
    'Cate 1',
    'Cate 2',
    'Cate 3'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기본 정보
              const Text(
                '기본 정보',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(
                    'Lat: ${widget.store.latitude}, Long: ${widget.store.longitude}'),
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(widget.store.contactNumber.replaceAllMapped(
                        RegExp(r'(\d{3})(\d{3})(\d{4})'),
                        (Match m) => '${m[1]}-${m[2]}-${m[3]}') ??
                    '전화번호 없음'),
              ),

              const SizedBox(height: 24),

              // 영업 시간과 해피 아워를 나란히 배치
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 영업 시간
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '영업 시간',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildBusinessHours(),
                      ],
                    ),
                  ),

                  // 해피 아워 (있을 경우에만 표시)
                  if (widget.store.happyHours?.isNotEmpty ?? false)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '해피 아워',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildHappyHours(),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 24),

              // 메뉴 카테고리
              const Text(
                '메뉴',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(_categories[index]),
                        selected: _selectedCategory == _categories[index],
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedCategory = _categories[index];
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildMenuList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessHours() {
    if (widget.store.is24Hours) {
      return const Text('24시간 영업');
    }

    final List<String> days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Column(
      children: days.map((day) {
        // 해당 요일의 영업시간 찾기
        var dayHours = widget.store.businessHours?.firstWhere(
          (hours) => hours.daysOfWeek.contains(day),
          orElse: () => BusinessHours(
            openHour: 0,
            openMinute: 0,
            closeHour: 0,
            closeMinute: 0,
            daysOfWeek: [],
          ),
        );

        // 영업시간 문자열 생성
        String hours = dayHours?.daysOfWeek.isEmpty ?? true
            ? '휴무'
            : '${dayHours!.openHour}:${dayHours.openMinute.toString().padLeft(2, '0')} - ${dayHours.closeHour}:${dayHours.closeMinute.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(day),
              ),
              Text(hours),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHappyHours() {
    final List<String> days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Column(
      children: days.map((day) {
        // 해당 요일의 해피아워 찾기
        var dayHours = widget.store.happyHours?.firstWhere(
          (hours) => hours.daysOfWeek.contains(day),
          orElse: () => HappyHour(
            startHour: 0,
            startMinute: 0,
            endHour: 0,
            endMinute: 0,
            daysOfWeek: [],
          ),
        );

        // 해피아워 문자열 생성
        String hours = dayHours?.daysOfWeek.isEmpty ?? true
            ? '-'
            : '${dayHours!.startHour}:${dayHours.startMinute.toString().padLeft(2, '0')} - ${dayHours.endHour}:${dayHours.endMinute.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(day),
              ),
              Text(hours),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMenuList() {
    if (widget.store.menus.isEmpty) {
      return const Text('메뉴 정보가 없습니다.');
    }

    var filteredMenus = widget.store.menus
        .where((menu) => menu.type == _selectedCategory)
        .toList();

    if (filteredMenus.isEmpty) {
      return const Text('해당 카테고리의 메뉴가 없습니다.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredMenus.length,
      itemBuilder: (context, index) {
        final menu = filteredMenus[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(menu.name),
              Text('\$${menu.price.toStringAsFixed(2)}'),
            ],
          ),
        );
      },
    );
  }
}
