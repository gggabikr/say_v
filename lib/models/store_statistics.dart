class StoreStatistics {
  final String storeId;
  final int pageViews; // 상세 페이지 조회수
  final int mapClicks; // 지도 클릭수
  final int phoneClicks; // 전화번호 클릭수
  final int searchAppearances; // 검색결과 노출수
  final DateTime lastUpdated;

  StoreStatistics({
    required this.storeId,
    this.pageViews = 0,
    this.mapClicks = 0,
    this.phoneClicks = 0,
    this.searchAppearances = 0,
    required this.lastUpdated,
  });

  factory StoreStatistics.fromJson(Map<String, dynamic> json) {
    return StoreStatistics(
      storeId: json['storeId'],
      pageViews: json['pageViews'] ?? 0,
      mapClicks: json['mapClicks'] ?? 0,
      phoneClicks: json['phoneClicks'] ?? 0,
      searchAppearances: json['searchAppearances'] ?? 0,
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'storeId': storeId,
      'pageViews': pageViews,
      'mapClicks': mapClicks,
      'phoneClicks': phoneClicks,
      'searchAppearances': searchAppearances,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  StoreStatistics copyWith({
    int? pageViews,
    int? mapClicks,
    int? phoneClicks,
    int? searchAppearances,
  }) {
    return StoreStatistics(
      storeId: storeId,
      pageViews: pageViews ?? this.pageViews,
      mapClicks: mapClicks ?? this.mapClicks,
      phoneClicks: phoneClicks ?? this.phoneClicks,
      searchAppearances: searchAppearances ?? this.searchAppearances,
      lastUpdated: DateTime.now(),
    );
  }
}
