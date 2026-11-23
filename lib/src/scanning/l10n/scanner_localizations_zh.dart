// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'scanner_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class ScannerLocalizationsZh extends ScannerLocalizations {
  ScannerLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get close => '关闭扫描';

  @override
  String get torchOn => '打开手电筒';

  @override
  String get torchOff => '关闭手电筒';

  @override
  String get switchCamera => '切换摄像头';

  @override
  String get pickImage => '从照片识别';

  @override
  String get zoom => '缩放';

  @override
  String get autoZoom => '自动';

  @override
  String get autoZoomOn => '开启自动缩放';

  @override
  String get autoZoomOff => '关闭自动缩放';

  @override
  String get starting => '正在启动相机…';

  @override
  String get permissionTitle => '相机权限已关闭';

  @override
  String get permissionMessage => '请在“设置”中允许此应用访问相机，以便扫码。';

  @override
  String get unavailableTitle => '相机不可用';

  @override
  String get unavailableMessage => '相机可能正被其他应用使用，或此设备没有相机。';

  @override
  String get inUseMessage => '其他应用正在使用相机。请关闭该应用后重试。';

  @override
  String get unsupportedMessage => '此处无法使用相机。在网页中，页面须通过https打开。';

  @override
  String get photoFallback => '你仍可从照片中识别条码。';

  @override
  String get openSettings => '打开设置';

  @override
  String get tryAgain => '重试';

  @override
  String get choosePhoto => '选择照片';

  @override
  String get noCodeInPhoto => '照片中未发现条码';

  @override
  String get backToCamera => '返回相机';

  @override
  String get backToCodes => '返回条码列表';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get scanAgain => '重新扫描';

  @override
  String get done => '完成';

  @override
  String get scanned => '已扫描';

  @override
  String get emptyList => '扫描的条码将显示在这里';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count项',
    );
    return '$_temp0';
  }

  @override
  String byteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count字节',
    );
    return '$_temp0';
  }

  @override
  String get link => '链接';

  @override
  String get wifi => 'Wi‑Fi网络';

  @override
  String get wifiPassword => '密码已包含在码中';

  @override
  String wifiSecurity(String security) {
    String _temp0 = intl.Intl.selectLogic(security, {
      'none': '开放网络',
      'wep': 'WEP',
      'wpa': 'WPA',
      'wpa3': 'WPA3',
      'enterprise': '企业级',
      'other': '已加密',
    });
    return '$_temp0';
  }

  @override
  String get contact => '联系人';

  @override
  String get event => '日程';

  @override
  String get email => '电子邮件';

  @override
  String get phone => '电话';

  @override
  String get sms => '短信';

  @override
  String get location => '位置';

  @override
  String get gs1 => 'GS1';

  @override
  String get faceTime => 'FaceTime';

  @override
  String get payment => '付款';

  @override
  String get otp => '一次性密码';

  @override
  String get esim => 'eSIM';

  @override
  String get crypto => '加密货币付款';

  @override
  String get wifiDevice => 'Wi‑Fi设备';

  @override
  String get smartHome => '智能家居设备';

  @override
  String get boardingPass => '登机牌';

  @override
  String get driverLicense => '驾驶证';

  @override
  String get vehicle => '车辆';

  @override
  String get product => '商品';

  @override
  String get book => '图书';

  @override
  String get secret => '密钥';

  @override
  String get show => '显示';

  @override
  String get hide => '隐藏';

  @override
  String get otpType => '类型';

  @override
  String get otpTimeBased => '基于时间';

  @override
  String get otpCounterBased => '基于计数器';

  @override
  String get otpDigits => '位数';

  @override
  String get otpPeriod => '间隔';

  @override
  String get otpCounter => '计数器';

  @override
  String seconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get matchingId => '匹配ID';

  @override
  String get confirmationCode => '确认码';

  @override
  String get needed => '需要';

  @override
  String get setupCode => '设置代码';

  @override
  String get vendorId => '厂商';

  @override
  String get productId => '产品';

  @override
  String get discriminator => '鉴别码';

  @override
  String get category => '类别';

  @override
  String get setupId => '设置ID';

  @override
  String get gtin => 'GTIN';

  @override
  String get addOn => '附加码';

  @override
  String get passenger => '旅客';

  @override
  String get date => '日期';

  @override
  String get seat => '座位';

  @override
  String get cabin => '舱位';

  @override
  String get booking => '订座记录';

  @override
  String get sequence => '序号';

  @override
  String flightOf(int flight, int count) {
    return '第$flight段航班，共$count段';
  }

  @override
  String get licenseNumber => '证号';

  @override
  String get born => '出生日期';

  @override
  String get expires => '有效期至';

  @override
  String get city => '城市';

  @override
  String get state => '州/省';

  @override
  String get country => '国家/地区';

  @override
  String get expired => '已过期';

  @override
  String get makerCode => '制造厂代码';

  @override
  String get modelYear => '车型年份';

  @override
  String get checkDigit => '校验位';

  @override
  String get valid => '有效';

  @override
  String get macAddress => 'MAC';

  @override
  String get channels => '信道';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': '1月',
      'feb': '2月',
      'mar': '3月',
      'apr': '4月',
      'may': '5月',
      'jun': '6月',
      'jul': '7月',
      'aug': '8月',
      'sep': '9月',
      'oct': '10月',
      'nov': '11月',
      'dec': '12月',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String dayMonth(int day, String month) {
    return '$month$day日';
  }

  @override
  String dayMonthYear(int day, String month, int year) {
    return '$year年$month$day日';
  }

  @override
  String vinRegion(String region) {
    String _temp0 = intl.Intl.selectLogic(region, {
      'africa': '非洲',
      'asia': '亚洲',
      'europe': '欧洲',
      'northAmerica': '北美洲',
      'oceania': '大洋洲',
      'southAmerica': '南美洲',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String amount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get anyAmount => '任意金额';

  @override
  String get payerEntersAmount => '由付款人输入金额';

  @override
  String get reusable => '可重复使用';

  @override
  String get copyIban => '复制IBAN';

  @override
  String get copyAccount => '复制账号';

  @override
  String get copyUpiId => '复制UPI ID';

  @override
  String get copyPixKey => '复制密钥';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get accountNumber => '账号';

  @override
  String get paymentReference => '附言';

  @override
  String get address => '地址';

  @override
  String get payableBy => '付款人';

  @override
  String get bank => '银行';

  @override
  String get inn => 'INN';

  @override
  String get kpp => 'KPP';

  @override
  String get upiId => 'UPI ID';

  @override
  String get pixKey => 'PIX密钥';

  @override
  String get transaction => '交易';

  @override
  String get variableSymbol => '可变符号';

  @override
  String get binary => '二进制数据';

  @override
  String get text => '文本';

  @override
  String get batch => '批号';

  @override
  String get serial => '序列号';

  @override
  String get sscc => 'SSCC';

  @override
  String get quantity => '数量';

  @override
  String get bestBefore => '最佳食用期至';

  @override
  String get loyaltyCard => '会员卡';

  @override
  String get cardNumber => '卡号';

  @override
  String get accepted => '已通过';

  @override
  String get needsAttention => '请检查此码';

  @override
  String get rejected => '未通过';

  @override
  String checkedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已签到：$count',
    );
    return '$_temp0';
  }

  @override
  String codesInView(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count个条码',
    );
    return '$_temp0';
  }

  @override
  String get pickCode => '选择此码';

  @override
  String get scanCode => '扫码';

  @override
  String get hintCode => '将相机对准条码';

  @override
  String get hintQrCode => '对准二维码';

  @override
  String get hintBarcode => '对准条形码';

  @override
  String get hintCloser => '请靠近一些';

  @override
  String get hintTicket => '对准票券';

  @override
  String get hintDataMatrix => '对准Data Matrix码';

  @override
  String get hintPick => '点按条码';

  @override
  String get hintKiosk => '将码对准摄像头';

  @override
  String get hintVin => '前挡风玻璃或车门立柱';

  @override
  String get hintCard => '对准卡上的条码';

  @override
  String get hintField => '对准条码';

  @override
  String get titlePayment => '扫码付款';

  @override
  String get titleTicket => '扫描门票';

  @override
  String get titleSignIn => '扫码登录';
}
