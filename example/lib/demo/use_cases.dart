// The Use cases tab's list: each case is one file in lib/use_cases/, which
// the tab opens and shows as code.
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../use_cases/add_2fa.dart';
import '../use_cases/boarding_pass.dart';
import '../use_cases/business_card.dart';
import '../use_cases/door_check_in.dart';
import '../use_cases/invoice_qr.dart';
import '../use_cases/join_wifi.dart';
import '../use_cases/kiosk.dart';
import '../use_cases/label_sheet.dart';
import '../use_cases/loyalty_card.dart';
import '../use_cases/medicine_pack.dart';
import '../use_cases/open_link.dart';
import '../use_cases/parcels.dart';
import '../use_cases/pay_by_qr.dart';
import '../use_cases/pick_one.dart';
import '../use_cases/product_lookup.dart';
import '../use_cases/profile_qr.dart';
import '../use_cases/read_from_photo.dart';
import '../use_cases/scan_button.dart';
import '../use_cases/scan_into_form.dart';
import '../use_cases/sign_in_with_qr.dart';
import '../use_cases/stocktake.dart';
import '../use_cases/ticket_card.dart';
import '../use_cases/vin.dart';
import '../use_cases/wifi_for_guests.dart';

enum UseCaseGroup {
  scan('Scanning'),
  create('Creating codes');

  const UseCaseGroup(this.label);
  final String label;
}

@immutable
class UseCase {
  const UseCase({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.group,
    required this.builder,
    this.needs = const <String>[],
  });

  /// The file's name in lib/use_cases/ without `.dart`; also `?case=` on
  /// the web and `--dart-define=CASE=`.
  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final UseCaseGroup group;
  final WidgetBuilder builder;

  /// Packages the case needs besides flutter_zxing.
  final List<String> needs;

  String get file => 'lib/use_cases/$id.dart';
}

final List<UseCase> useCases = <UseCase>[
  UseCase(
    id: 'scan_button',
    title: 'A scan button',
    summary: 'One code, then back to your screen',
    icon: Icons.qr_code_scanner_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const ScanButtonPage(),
  ),
  UseCase(
    id: 'scan_into_form',
    title: 'Scan into a form',
    summary: 'A serial number, IMEI or tracking number into a text field',
    icon: Icons.edit_note_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const ScanIntoFormPage(),
  ),
  UseCase(
    id: 'sign_in_with_qr',
    title: 'Sign in on another screen',
    summary: 'Your TV or web app shows a QR code, the phone confirms',
    icon: Icons.devices_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const SignInWithQrPage(),
  ),
  UseCase(
    id: 'open_link',
    title: 'Open a link safely',
    summary: 'Show where a QR code leads before opening it',
    icon: Icons.link_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const OpenLinkPage(),
    needs: <String>['url_launcher'],
  ),
  UseCase(
    id: 'join_wifi',
    title: 'Wi‑Fi from a QR code',
    summary: 'The network and its password, copied in a tap',
    icon: Icons.wifi_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const JoinWifiPage(),
  ),
  UseCase(
    id: 'pay_by_qr',
    title: 'Pay by QR code',
    summary: 'SEPA, Swiss QR-bill, UPI, PIX… into your payment screen',
    icon: Icons.payments_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const PayByQrPage(),
  ),
  UseCase(
    id: 'product_lookup',
    title: 'Look up a product',
    summary: 'EAN, UPC or ISBN into your catalogue',
    icon: Icons.shopping_bag_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const ProductLookupPage(),
  ),
  UseCase(
    id: 'boarding_pass',
    title: 'Boarding pass',
    summary: 'Passenger, flight and seat from the pass',
    icon: Icons.flight_takeoff_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const BoardingPassPage(),
  ),
  UseCase(
    id: 'door_check_in',
    title: 'Tickets at the door',
    summary: 'Each ticket checked against the guest list, nonstop',
    icon: Icons.how_to_reg_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const DoorCheckInPage(),
  ),
  UseCase(
    id: 'stocktake',
    title: 'Stocktake',
    summary: 'Many barcodes in a row, with counts',
    icon: Icons.inventory_2_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const StocktakePage(),
  ),
  UseCase(
    id: 'parcels',
    title: 'Receive parcels',
    summary: 'GS1-128 shipping labels: SSCC, GTIN, quantity, batch',
    icon: Icons.local_shipping_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const ParcelsPage(),
  ),
  UseCase(
    id: 'loyalty_card',
    title: 'Loyalty card at the till',
    summary: 'The card number from its barcode, large',
    icon: Icons.card_membership_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const LoyaltyCardPage(),
  ),
  UseCase(
    id: 'medicine_pack',
    title: 'Medicine pack',
    summary: 'Batch, serial and expiry from the Data Matrix',
    icon: Icons.medication_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const MedicinePackPage(),
  ),
  UseCase(
    id: 'vin',
    title: 'Vehicle VIN',
    summary: 'The maker and model year from the windshield code',
    icon: Icons.directions_car_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const VinPage(),
  ),
  UseCase(
    id: 'kiosk',
    title: 'Self-service kiosk',
    summary: 'The front camera, large text, no buttons',
    icon: Icons.storefront_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const KioskPage(),
  ),
  UseCase(
    id: 'pick_one',
    title: 'Pick one of many',
    summary: 'Several codes in view, tap the one you need',
    icon: Icons.touch_app_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const PickOnePage(),
  ),
  UseCase(
    id: 'read_from_photo',
    title: 'Read from a photo',
    summary: 'A screenshot or a picture from the gallery',
    icon: Icons.photo_library_outlined,
    group: UseCaseGroup.scan,
    builder: (_) => const ReadFromPhotoPage(),
    needs: <String>['image_picker'],
  ),
  UseCase(
    id: 'add_2fa',
    title: 'Add a 2FA account',
    summary: 'An otpauth:// code into your authenticator',
    icon: Icons.password_rounded,
    group: UseCaseGroup.scan,
    builder: (_) => const AddTwoFactorPage(),
  ),
  UseCase(
    id: 'profile_qr',
    title: 'My profile QR code',
    summary: 'A styled QR code of a profile link, shared as an image',
    icon: Icons.qr_code_2_rounded,
    group: UseCaseGroup.create,
    builder: (_) => const ProfileQrPage(),
    needs: <String>['share_plus'],
  ),
  UseCase(
    id: 'ticket_card',
    title: 'A ticket in the app',
    summary: 'A ticket card with the code the door scans',
    icon: Icons.confirmation_number_outlined,
    group: UseCaseGroup.create,
    builder: (_) => const TicketCardPage(),
  ),
  UseCase(
    id: 'wifi_for_guests',
    title: 'Wi‑Fi card for guests',
    summary: 'A QR code that joins the network, to print or share',
    icon: Icons.wifi_password_rounded,
    group: UseCaseGroup.create,
    builder: (_) => const WifiForGuestsPage(),
    needs: <String>['share_plus'],
  ),
  UseCase(
    id: 'invoice_qr',
    title: 'A QR code on an invoice',
    summary: 'A SEPA or Swiss QR-bill payment code',
    icon: Icons.receipt_long_outlined,
    group: UseCaseGroup.create,
    builder: (_) => const InvoiceQrPage(),
  ),
  UseCase(
    id: 'label_sheet',
    title: 'A sheet of labels',
    summary: 'Many codes on an A4 page in columns, as SVG for print',
    icon: Icons.grid_view_rounded,
    group: UseCaseGroup.create,
    builder: (_) => const LabelSheetPage(),
    needs: <String>['share_plus'],
  ),
  UseCase(
    id: 'business_card',
    title: 'Business card',
    summary: 'A vCard QR code that saves your contact',
    icon: Icons.contact_page_outlined,
    group: UseCaseGroup.create,
    builder: (_) => const BusinessCardPage(),
  ),
];
