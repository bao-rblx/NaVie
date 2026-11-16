import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'NaVie'**
  String get appTitle;

  /// No description provided for @searchOrigin.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đi'**
  String get searchOrigin;

  /// No description provided for @searchDestination.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đến'**
  String get searchDestination;

  /// No description provided for @modeWalk.
  ///
  /// In vi, this message translates to:
  /// **'Đi bộ'**
  String get modeWalk;

  /// No description provided for @modeMotorbike.
  ///
  /// In vi, this message translates to:
  /// **'Xe máy'**
  String get modeMotorbike;

  /// No description provided for @modeCar.
  ///
  /// In vi, this message translates to:
  /// **'Ô tô'**
  String get modeCar;

  /// No description provided for @modeTaxi.
  ///
  /// In vi, this message translates to:
  /// **'Taxi'**
  String get modeTaxi;

  /// No description provided for @findRoute.
  ///
  /// In vi, this message translates to:
  /// **'Tìm đường'**
  String get findRoute;

  /// No description provided for @startNavigation.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu'**
  String get startNavigation;

  /// No description provided for @estimateLabel.
  ///
  /// In vi, this message translates to:
  /// **'ước tính'**
  String get estimateLabel;

  /// No description provided for @errorOutOfCoverage.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí nằm ngoài vùng bản đồ được hỗ trợ.'**
  String get errorOutOfCoverage;

  /// No description provided for @errorNoPath.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy đường đi.'**
  String get errorNoPath;

  /// No description provided for @osmAttribution.
  ///
  /// In vi, this message translates to:
  /// **'© OpenStreetMap contributors'**
  String get osmAttribution;

  /// No description provided for @mapPreview.
  ///
  /// In vi, this message translates to:
  /// **'Bản đồ tuyến đường'**
  String get mapPreview;

  /// No description provided for @settings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settings;

  /// No description provided for @routeOptions.
  ///
  /// In vi, this message translates to:
  /// **'Lựa chọn tuyến đường'**
  String get routeOptions;

  /// No description provided for @coordinateHintOrigin.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đi [vĩ độ, kinh độ]'**
  String get coordinateHintOrigin;

  /// No description provided for @coordinateHintDestination.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đến [vĩ độ, kinh độ]'**
  String get coordinateHintDestination;

  /// No description provided for @invalidCoordinate.
  ///
  /// In vi, this message translates to:
  /// **'Nhập tọa độ theo dạng vĩ độ, kinh độ.'**
  String get invalidCoordinate;

  /// No description provided for @serverUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không thể kết nối máy chủ NaVie.'**
  String get serverUnavailable;

  /// No description provided for @chooseOrigin.
  ///
  /// In vi, this message translates to:
  /// **'Chọn điểm đi trên bản đồ'**
  String get chooseOrigin;

  /// No description provided for @chooseDestination.
  ///
  /// In vi, this message translates to:
  /// **'Chọn điểm đến trên bản đồ'**
  String get chooseDestination;

  /// No description provided for @chooseBothPoints.
  ///
  /// In vi, this message translates to:
  /// **'Hãy chọn điểm đi và điểm đến trên bản đồ.'**
  String get chooseBothPoints;

  /// No description provided for @resetTrip.
  ///
  /// In vi, this message translates to:
  /// **'Làm mới chuyến đi'**
  String get resetTrip;

  /// No description provided for @mainNavigation.
  ///
  /// In vi, this message translates to:
  /// **'Điều hướng chính'**
  String get mainNavigation;

  /// No description provided for @explore.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá'**
  String get explore;

  /// No description provided for @saved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu'**
  String get saved;

  /// No description provided for @lab.
  ///
  /// In vi, this message translates to:
  /// **'Thuật toán'**
  String get lab;

  /// No description provided for @madeForYourEveryday.
  ///
  /// In vi, this message translates to:
  /// **'CHO MỌI HÀNH TRÌNH'**
  String get madeForYourEveryday;

  /// No description provided for @whereTo.
  ///
  /// In vi, this message translates to:
  /// **'Hôm nay, đi đâu?'**
  String get whereTo;

  /// No description provided for @journeySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Một hành trình tốt bắt đầu từ đây.'**
  String get journeySubtitle;

  /// No description provided for @originPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Tìm điểm xuất phát'**
  String get originPlaceholder;

  /// No description provided for @destinationPlaceholder.
  ///
  /// In vi, this message translates to:
  /// **'Bạn muốn đến đâu?'**
  String get destinationPlaceholder;

  /// No description provided for @swapPlaces.
  ///
  /// In vi, this message translates to:
  /// **'Đổi điểm đi và điểm đến'**
  String get swapPlaces;

  /// No description provided for @useMyLocation.
  ///
  /// In vi, this message translates to:
  /// **'Dùng vị trí của tôi'**
  String get useMyLocation;

  /// No description provided for @travelYourWay.
  ///
  /// In vi, this message translates to:
  /// **'Đi theo cách của bạn'**
  String get travelYourWay;

  /// No description provided for @compareAll.
  ///
  /// In vi, this message translates to:
  /// **'So sánh'**
  String get compareAll;

  /// No description provided for @aLittleCloser.
  ///
  /// In vi, this message translates to:
  /// **'Gần hơn một chút'**
  String get aLittleCloser;

  /// No description provided for @yourCityYourPace.
  ///
  /// In vi, this message translates to:
  /// **'Thành phố của bạn. Nhịp điệu của bạn.'**
  String get yourCityYourPace;

  /// No description provided for @mapHelp.
  ///
  /// In vi, this message translates to:
  /// **'Tìm một địa điểm hoặc chọn điểm đi và điểm đến ngay trên bản đồ.'**
  String get mapHelp;

  /// No description provided for @coverageNote.
  ///
  /// In vi, this message translates to:
  /// **'Đường phố TP.HCM · Không cần tài khoản'**
  String get coverageNote;

  /// No description provided for @sortRoutes.
  ///
  /// In vi, this message translates to:
  /// **'Sắp xếp tuyến đường'**
  String get sortRoutes;

  /// No description provided for @fastest.
  ///
  /// In vi, this message translates to:
  /// **'Nhanh nhất'**
  String get fastest;

  /// No description provided for @cheapest.
  ///
  /// In vi, this message translates to:
  /// **'Rẻ nhất'**
  String get cheapest;

  /// No description provided for @balanced.
  ///
  /// In vi, this message translates to:
  /// **'Cân bằng'**
  String get balanced;

  /// No description provided for @previewDrive.
  ///
  /// In vi, this message translates to:
  /// **'Xem thử hành trình'**
  String get previewDrive;

  /// No description provided for @yourPlaces.
  ///
  /// In vi, this message translates to:
  /// **'NHỮNG NƠI THÂN QUEN'**
  String get yourPlaces;

  /// No description provided for @savedSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Những điểm đến yêu thích, luôn trong tầm tay.'**
  String get savedSubtitle;

  /// No description provided for @saveDestination.
  ///
  /// In vi, this message translates to:
  /// **'Lưu điểm đến'**
  String get saveDestination;

  /// No description provided for @behindTheRoute.
  ///
  /// In vi, this message translates to:
  /// **'PHÍA SAU MỖI TUYẾN ĐƯỜNG'**
  String get behindTheRoute;

  /// No description provided for @labSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Khám phá cách thuật toán tìm đường cho bạn.'**
  String get labSubtitle;

  /// No description provided for @labHelp.
  ///
  /// In vi, this message translates to:
  /// **'Chọn điểm đi và điểm đến ở mục Khám phá, rồi so sánh hai thuật toán trên cùng chuyến đi.'**
  String get labHelp;

  /// No description provided for @compareAlgorithms.
  ///
  /// In vi, this message translates to:
  /// **'So sánh thuật toán'**
  String get compareAlgorithms;

  /// No description provided for @makeItYours.
  ///
  /// In vi, this message translates to:
  /// **'THEO CÁCH CỦA BẠN'**
  String get makeItYours;

  /// No description provided for @settingsSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Một vài điều chỉnh cho hành trình dễ chịu hơn.'**
  String get settingsSubtitle;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get appearance;

  /// No description provided for @dayTheme.
  ///
  /// In vi, this message translates to:
  /// **'Ban ngày'**
  String get dayTheme;

  /// No description provided for @nightTheme.
  ///
  /// In vi, this message translates to:
  /// **'Ban đêm'**
  String get nightTheme;

  /// No description provided for @systemTheme.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống'**
  String get systemTheme;

  /// No description provided for @voiceGuidance.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn giọng nói'**
  String get voiceGuidance;

  /// No description provided for @reduceMotion.
  ///
  /// In vi, this message translates to:
  /// **'Giảm chuyển động'**
  String get reduceMotion;

  /// No description provided for @privacyTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chuyến đi của bạn, riêng tư.'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm và tùy chọn được lưu trên thiết bị này. Vị trí chỉ được dùng khi bạn yêu cầu; tọa độ được gửi đến máy chủ NaVie để tìm đường. Không gửi lịch sử GPS.'**
  String get privacyBody;

  /// No description provided for @clearSaved.
  ///
  /// In vi, this message translates to:
  /// **'Xóa địa điểm đã lưu và gần đây'**
  String get clearSaved;

  /// No description provided for @appLimitations.
  ///
  /// In vi, this message translates to:
  /// **'Phạm vi hiện tại: đường phố TP.HCM. Chưa có giao thông trực tiếp, báo sự cố hay giá vé đã xác minh.'**
  String get appLimitations;

  /// No description provided for @footerTagline.
  ///
  /// In vi, this message translates to:
  /// **'Đi theo cách của bạn.'**
  String get footerTagline;

  /// No description provided for @exploreCity.
  ///
  /// In vi, this message translates to:
  /// **'Một góc Việt Nam, vô vàn hành trình'**
  String get exploreCity;

  /// No description provided for @togglePanel.
  ///
  /// In vi, this message translates to:
  /// **'Ẩn hoặc mở bảng điều khiển'**
  String get togglePanel;

  /// No description provided for @toggleTheme.
  ///
  /// In vi, this message translates to:
  /// **'Đổi giao diện ngày đêm'**
  String get toggleTheme;

  /// No description provided for @zoomIn.
  ///
  /// In vi, this message translates to:
  /// **'Phóng to'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhỏ'**
  String get zoomOut;

  /// No description provided for @recenter.
  ///
  /// In vi, this message translates to:
  /// **'Căn giữa bản đồ'**
  String get recenter;

  /// No description provided for @northUp.
  ///
  /// In vi, this message translates to:
  /// **'Hướng Bắc ở trên'**
  String get northUp;

  /// No description provided for @mapHint.
  ///
  /// In vi, this message translates to:
  /// **'Kéo để khám phá · Cuộn để phóng to'**
  String get mapHint;

  /// No description provided for @driverMode.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ dẫn đường'**
  String get driverMode;

  /// No description provided for @speedLimit.
  ///
  /// In vi, this message translates to:
  /// **'Giới hạn'**
  String get speedLimit;

  /// No description provided for @remaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn lại'**
  String get remaining;

  /// No description provided for @distance.
  ///
  /// In vi, this message translates to:
  /// **'Khoảng cách'**
  String get distance;

  /// No description provided for @arrivalTime.
  ///
  /// In vi, this message translates to:
  /// **'Đến nơi · VN'**
  String get arrivalTime;

  /// No description provided for @simulation.
  ///
  /// In vi, this message translates to:
  /// **'Mô phỏng'**
  String get simulation;

  /// No description provided for @pauseResume.
  ///
  /// In vi, this message translates to:
  /// **'Tạm dừng hoặc tiếp tục'**
  String get pauseResume;

  /// No description provided for @playbackSpeed.
  ///
  /// In vi, this message translates to:
  /// **'Tốc độ phát'**
  String get playbackSpeed;

  /// No description provided for @routeOverview.
  ///
  /// In vi, this message translates to:
  /// **'Toàn tuyến'**
  String get routeOverview;

  /// No description provided for @endNavigation.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc'**
  String get endNavigation;

  /// No description provided for @niceJourney.
  ///
  /// In vi, this message translates to:
  /// **'THÊM MỘT HÀNH TRÌNH'**
  String get niceJourney;

  /// No description provided for @youArrived.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đã đến nơi.'**
  String get youArrived;

  /// No description provided for @done.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn tất'**
  String get done;

  /// No description provided for @storageUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu tùy chọn trên thiết bị này.'**
  String get storageUnavailable;

  /// No description provided for @minutesShort.
  ///
  /// In vi, this message translates to:
  /// **'phút'**
  String get minutesShort;

  /// No description provided for @hoursShort.
  ///
  /// In vi, this message translates to:
  /// **'giờ'**
  String get hoursShort;

  /// No description provided for @findingRoute.
  ///
  /// In vi, this message translates to:
  /// **'Đang tìm đường…'**
  String get findingRoute;

  /// No description provided for @searchingPlaces.
  ///
  /// In vi, this message translates to:
  /// **'Đang tìm địa điểm…'**
  String get searchingPlaces;

  /// No description provided for @noPlaces.
  ///
  /// In vi, this message translates to:
  /// **'Chưa tìm thấy địa điểm. Thử tên khác hoặc chọn trên bản đồ.'**
  String get noPlaces;

  /// No description provided for @place.
  ///
  /// In vi, this message translates to:
  /// **'Địa điểm'**
  String get place;

  /// No description provided for @mapPin.
  ///
  /// In vi, this message translates to:
  /// **'Điểm đã chọn trên bản đồ'**
  String get mapPin;

  /// No description provided for @locationUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Thiết bị không hỗ trợ vị trí. Hãy chọn trên bản đồ.'**
  String get locationUnavailable;

  /// No description provided for @findingLocation.
  ///
  /// In vi, this message translates to:
  /// **'Đang xác định vị trí…'**
  String get findingLocation;

  /// No description provided for @myLocation.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí của tôi'**
  String get myLocation;

  /// No description provided for @locationDenied.
  ///
  /// In vi, this message translates to:
  /// **'Không thể lấy vị trí. Cho phép truy cập GPS hoặc dùng Xem thử hành trình.'**
  String get locationDenied;

  /// No description provided for @priceUnavailable.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có giá xác minh'**
  String get priceUnavailable;

  /// No description provided for @routeEstimateNote.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian ước tính theo dữ liệu đường phố; chưa tính giao thông trực tiếp.'**
  String get routeEstimateNote;

  /// No description provided for @distanceMeters.
  ///
  /// In vi, this message translates to:
  /// **'{meters} m'**
  String distanceMeters(int meters);

  /// No description provided for @distanceKilometers.
  ///
  /// In vi, this message translates to:
  /// **'{kilometers} km'**
  String distanceKilometers(String kilometers);

  /// No description provided for @playbackMultiplier.
  ///
  /// In vi, this message translates to:
  /// **'{speed}×'**
  String playbackMultiplier(int speed);

  /// No description provided for @speedValue.
  ///
  /// In vi, this message translates to:
  /// **'{kilometersPerHour} km/h'**
  String speedValue(int kilometersPerHour);

  /// No description provided for @speedUnknown.
  ///
  /// In vi, this message translates to:
  /// **'— km/h'**
  String get speedUnknown;

  /// No description provided for @speedLimitUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Giới hạn: —'**
  String get speedLimitUnknown;

  /// No description provided for @metaSeparator.
  ///
  /// In vi, this message translates to:
  /// **'·'**
  String get metaSeparator;

  /// No description provided for @pricingUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Dữ liệu giá'**
  String get pricingUpdated;

  /// No description provided for @notVerified.
  ///
  /// In vi, this message translates to:
  /// **'Chưa xác minh'**
  String get notVerified;

  /// No description provided for @directions.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ dẫn từng chặng'**
  String get directions;

  /// No description provided for @placeSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu điểm đến.'**
  String get placeSaved;

  /// No description provided for @noSavedPlaces.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có địa điểm đã lưu. Tìm một điểm đến trong Khám phá rồi lưu lại tại đây.'**
  String get noSavedPlaces;

  /// No description provided for @savedOnDevice.
  ///
  /// In vi, this message translates to:
  /// **'Lưu trên thiết bị này'**
  String get savedOnDevice;

  /// No description provided for @removePlace.
  ///
  /// In vi, this message translates to:
  /// **'Xóa địa điểm'**
  String get removePlace;

  /// No description provided for @recentPlaces.
  ///
  /// In vi, this message translates to:
  /// **'Gần đây'**
  String get recentPlaces;

  /// No description provided for @useAsDestination.
  ///
  /// In vi, this message translates to:
  /// **'Chọn làm điểm đến'**
  String get useAsDestination;

  /// No description provided for @previewStarted.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu mô phỏng hành trình.'**
  String get previewStarted;

  /// No description provided for @waitingGps.
  ///
  /// In vi, this message translates to:
  /// **'Đang chờ GPS…'**
  String get waitingGps;

  /// No description provided for @gpsActive.
  ///
  /// In vi, this message translates to:
  /// **'Đang dẫn đường bằng GPS'**
  String get gpsActive;

  /// No description provided for @gpsWeak.
  ///
  /// In vi, this message translates to:
  /// **'GPS chưa chính xác · Đang chờ tín hiệu tốt hơn'**
  String get gpsWeak;

  /// No description provided for @rerouting.
  ///
  /// In vi, this message translates to:
  /// **'Đang tìm lại đường…'**
  String get rerouting;

  /// No description provided for @simulationPaused.
  ///
  /// In vi, this message translates to:
  /// **'Mô phỏng đã tạm dừng'**
  String get simulationPaused;

  /// No description provided for @continueToDestination.
  ///
  /// In vi, this message translates to:
  /// **'Tiếp tục đến điểm đến'**
  String get continueToDestination;

  /// No description provided for @metersWord.
  ///
  /// In vi, this message translates to:
  /// **'mét'**
  String get metersWord;

  /// No description provided for @routeUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật tuyến đường.'**
  String get routeUpdated;

  /// No description provided for @rerouteFailed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa thể tìm lại đường. Kiểm tra kết nối; NaVie sẽ thử lại.'**
  String get rerouteFailed;

  /// No description provided for @runningComparison.
  ///
  /// In vi, this message translates to:
  /// **'Đang so sánh…'**
  String get runningComparison;

  /// No description provided for @nodesExpanded.
  ///
  /// In vi, this message translates to:
  /// **'Nút đã duyệt'**
  String get nodesExpanded;

  /// No description provided for @runtime.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian chạy'**
  String get runtime;

  /// No description provided for @memory.
  ///
  /// In vi, this message translates to:
  /// **'Bộ nhớ đỉnh'**
  String get memory;

  /// No description provided for @showExploration.
  ///
  /// In vi, this message translates to:
  /// **'Xem các nút đã duyệt'**
  String get showExploration;

  /// No description provided for @savedCleared.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa địa điểm đã lưu và gần đây.'**
  String get savedCleared;

  /// No description provided for @stopNavigation.
  ///
  /// In vi, this message translates to:
  /// **'Dừng dẫn đường'**
  String get stopNavigation;

  /// No description provided for @loading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải…'**
  String get loading;

  /// No description provided for @navigationReady.
  ///
  /// In vi, this message translates to:
  /// **'Sẵn sàng lên đường'**
  String get navigationReady;

  /// No description provided for @chooseTravelMode.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phương tiện'**
  String get chooseTravelMode;

  /// No description provided for @navigationPermission.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền vị trí để dẫn đường. Bạn vẫn có thể xem thử hành trình.'**
  String get navigationPermission;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
