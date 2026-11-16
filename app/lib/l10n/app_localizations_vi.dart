// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'NaVie';

  @override
  String get searchOrigin => 'Điểm đi';

  @override
  String get searchDestination => 'Điểm đến';

  @override
  String get modeWalk => 'Đi bộ';

  @override
  String get modeMotorbike => 'Xe máy';

  @override
  String get modeCar => 'Ô tô';

  @override
  String get modeTaxi => 'Taxi';

  @override
  String get findRoute => 'Tìm đường';

  @override
  String get startNavigation => 'Bắt đầu';

  @override
  String get estimateLabel => 'ước tính';

  @override
  String get errorOutOfCoverage => 'Vị trí nằm ngoài vùng bản đồ được hỗ trợ.';

  @override
  String get errorNoPath => 'Không tìm thấy đường đi.';

  @override
  String get osmAttribution => '© OpenStreetMap contributors';

  @override
  String get mapPreview => 'Bản đồ tuyến đường';

  @override
  String get settings => 'Cài đặt';

  @override
  String get routeOptions => 'Lựa chọn tuyến đường';

  @override
  String get coordinateHintOrigin => 'Điểm đi [vĩ độ, kinh độ]';

  @override
  String get coordinateHintDestination => 'Điểm đến [vĩ độ, kinh độ]';

  @override
  String get invalidCoordinate => 'Nhập tọa độ theo dạng vĩ độ, kinh độ.';

  @override
  String get serverUnavailable => 'Không thể kết nối máy chủ NaVie.';

  @override
  String get chooseOrigin => 'Chọn điểm đi trên bản đồ';

  @override
  String get chooseDestination => 'Chọn điểm đến trên bản đồ';

  @override
  String get chooseBothPoints => 'Hãy chọn điểm đi và điểm đến trên bản đồ.';

  @override
  String get resetTrip => 'Làm mới chuyến đi';

  @override
  String get mainNavigation => 'Điều hướng chính';

  @override
  String get explore => 'Khám phá';

  @override
  String get saved => 'Đã lưu';

  @override
  String get lab => 'Thuật toán';

  @override
  String get madeForYourEveryday => 'CHO MỌI HÀNH TRÌNH';

  @override
  String get whereTo => 'Hôm nay, đi đâu?';

  @override
  String get journeySubtitle => 'Một hành trình tốt bắt đầu từ đây.';

  @override
  String get originPlaceholder => 'Tìm điểm xuất phát';

  @override
  String get destinationPlaceholder => 'Bạn muốn đến đâu?';

  @override
  String get swapPlaces => 'Đổi điểm đi và điểm đến';

  @override
  String get useMyLocation => 'Dùng vị trí của tôi';

  @override
  String get travelYourWay => 'Đi theo cách của bạn';

  @override
  String get compareAll => 'So sánh';

  @override
  String get aLittleCloser => 'Gần hơn một chút';

  @override
  String get yourCityYourPace => 'Thành phố của bạn. Nhịp điệu của bạn.';

  @override
  String get mapHelp =>
      'Tìm một địa điểm hoặc chọn điểm đi và điểm đến ngay trên bản đồ.';

  @override
  String get coverageNote => 'Đường phố TP.HCM · Không cần tài khoản';

  @override
  String get sortRoutes => 'Sắp xếp tuyến đường';

  @override
  String get fastest => 'Nhanh nhất';

  @override
  String get cheapest => 'Rẻ nhất';

  @override
  String get balanced => 'Cân bằng';

  @override
  String get previewDrive => 'Xem thử hành trình';

  @override
  String get yourPlaces => 'NHỮNG NƠI THÂN QUEN';

  @override
  String get savedSubtitle => 'Những điểm đến yêu thích, luôn trong tầm tay.';

  @override
  String get saveDestination => 'Lưu điểm đến';

  @override
  String get behindTheRoute => 'PHÍA SAU MỖI TUYẾN ĐƯỜNG';

  @override
  String get labSubtitle => 'Khám phá cách thuật toán tìm đường cho bạn.';

  @override
  String get labHelp =>
      'Chọn điểm đi và điểm đến ở mục Khám phá, rồi so sánh hai thuật toán trên cùng chuyến đi.';

  @override
  String get compareAlgorithms => 'So sánh thuật toán';

  @override
  String get makeItYours => 'THEO CÁCH CỦA BẠN';

  @override
  String get settingsSubtitle =>
      'Một vài điều chỉnh cho hành trình dễ chịu hơn.';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get appearance => 'Giao diện';

  @override
  String get dayTheme => 'Ban ngày';

  @override
  String get nightTheme => 'Ban đêm';

  @override
  String get systemTheme => 'Hệ thống';

  @override
  String get voiceGuidance => 'Hướng dẫn giọng nói';

  @override
  String get reduceMotion => 'Giảm chuyển động';

  @override
  String get privacyTitle => 'Chuyến đi của bạn, riêng tư.';

  @override
  String get privacyBody =>
      'Địa điểm và tùy chọn được lưu trên thiết bị này. Vị trí chỉ được dùng khi bạn yêu cầu; tọa độ được gửi đến máy chủ NaVie để tìm đường. Không gửi lịch sử GPS.';

  @override
  String get clearSaved => 'Xóa địa điểm đã lưu và gần đây';

  @override
  String get appLimitations =>
      'Phạm vi hiện tại: đường phố TP.HCM. Chưa có giao thông trực tiếp, báo sự cố hay giá vé đã xác minh.';

  @override
  String get footerTagline => 'Đi theo cách của bạn.';

  @override
  String get exploreCity => 'Một góc Việt Nam, vô vàn hành trình';

  @override
  String get togglePanel => 'Ẩn hoặc mở bảng điều khiển';

  @override
  String get toggleTheme => 'Đổi giao diện ngày đêm';

  @override
  String get zoomIn => 'Phóng to';

  @override
  String get zoomOut => 'Thu nhỏ';

  @override
  String get recenter => 'Căn giữa bản đồ';

  @override
  String get northUp => 'Hướng Bắc ở trên';

  @override
  String get mapHint => 'Kéo để khám phá · Cuộn để phóng to';

  @override
  String get driverMode => 'Chế độ dẫn đường';

  @override
  String get speedLimit => 'Giới hạn';

  @override
  String get remaining => 'Còn lại';

  @override
  String get distance => 'Khoảng cách';

  @override
  String get arrivalTime => 'Đến nơi · VN';

  @override
  String get simulation => 'Mô phỏng';

  @override
  String get pauseResume => 'Tạm dừng hoặc tiếp tục';

  @override
  String get playbackSpeed => 'Tốc độ phát';

  @override
  String get routeOverview => 'Toàn tuyến';

  @override
  String get endNavigation => 'Kết thúc';

  @override
  String get niceJourney => 'THÊM MỘT HÀNH TRÌNH';

  @override
  String get youArrived => 'Bạn đã đến nơi.';

  @override
  String get done => 'Hoàn tất';

  @override
  String get storageUnavailable => 'Không thể lưu tùy chọn trên thiết bị này.';

  @override
  String get minutesShort => 'phút';

  @override
  String get hoursShort => 'giờ';

  @override
  String get findingRoute => 'Đang tìm đường…';

  @override
  String get searchingPlaces => 'Đang tìm địa điểm…';

  @override
  String get noPlaces =>
      'Chưa tìm thấy địa điểm. Thử tên khác hoặc chọn trên bản đồ.';

  @override
  String get place => 'Địa điểm';

  @override
  String get mapPin => 'Điểm đã chọn trên bản đồ';

  @override
  String get locationUnavailable =>
      'Thiết bị không hỗ trợ vị trí. Hãy chọn trên bản đồ.';

  @override
  String get findingLocation => 'Đang xác định vị trí…';

  @override
  String get myLocation => 'Vị trí của tôi';

  @override
  String get locationDenied =>
      'Không thể lấy vị trí. Cho phép truy cập GPS hoặc dùng Xem thử hành trình.';

  @override
  String get priceUnavailable => 'Chưa có giá xác minh';

  @override
  String get routeEstimateNote =>
      'Thời gian ước tính theo dữ liệu đường phố; chưa tính giao thông trực tiếp.';

  @override
  String distanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String distanceKilometers(String kilometers) {
    return '$kilometers km';
  }

  @override
  String playbackMultiplier(int speed) {
    return '$speed×';
  }

  @override
  String speedValue(int kilometersPerHour) {
    return '$kilometersPerHour km/h';
  }

  @override
  String get speedUnknown => '— km/h';

  @override
  String get speedLimitUnknown => 'Giới hạn: —';

  @override
  String get metaSeparator => '·';

  @override
  String get pricingUpdated => 'Dữ liệu giá';

  @override
  String get notVerified => 'Chưa xác minh';

  @override
  String get directions => 'Chỉ dẫn từng chặng';

  @override
  String get placeSaved => 'Đã lưu điểm đến.';

  @override
  String get noSavedPlaces =>
      'Chưa có địa điểm đã lưu. Tìm một điểm đến trong Khám phá rồi lưu lại tại đây.';

  @override
  String get savedOnDevice => 'Lưu trên thiết bị này';

  @override
  String get removePlace => 'Xóa địa điểm';

  @override
  String get recentPlaces => 'Gần đây';

  @override
  String get useAsDestination => 'Chọn làm điểm đến';

  @override
  String get previewStarted => 'Bắt đầu mô phỏng hành trình.';

  @override
  String get waitingGps => 'Đang chờ GPS…';

  @override
  String get gpsActive => 'Đang dẫn đường bằng GPS';

  @override
  String get gpsWeak => 'GPS chưa chính xác · Đang chờ tín hiệu tốt hơn';

  @override
  String get rerouting => 'Đang tìm lại đường…';

  @override
  String get simulationPaused => 'Mô phỏng đã tạm dừng';

  @override
  String get continueToDestination => 'Tiếp tục đến điểm đến';

  @override
  String get metersWord => 'mét';

  @override
  String get routeUpdated => 'Đã cập nhật tuyến đường.';

  @override
  String get rerouteFailed =>
      'Chưa thể tìm lại đường. Kiểm tra kết nối; NaVie sẽ thử lại.';

  @override
  String get runningComparison => 'Đang so sánh…';

  @override
  String get nodesExpanded => 'Nút đã duyệt';

  @override
  String get runtime => 'Thời gian chạy';

  @override
  String get memory => 'Bộ nhớ đỉnh';

  @override
  String get showExploration => 'Xem các nút đã duyệt';

  @override
  String get savedCleared => 'Đã xóa địa điểm đã lưu và gần đây.';

  @override
  String get stopNavigation => 'Dừng dẫn đường';

  @override
  String get loading => 'Đang tải…';

  @override
  String get navigationReady => 'Sẵn sàng lên đường';

  @override
  String get chooseTravelMode => 'Chọn phương tiện';

  @override
  String get navigationPermission =>
      'Cần quyền vị trí để dẫn đường. Bạn vẫn có thể xem thử hành trình.';

  @override
  String get cancel => 'Hủy';
}
