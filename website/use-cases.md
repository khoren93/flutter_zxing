# Use cases

How apps use flutter_zxing, each case one file to copy into your app. It
imports only `flutter_zxing` and Flutter, plus the package it names. The
same files run in the demo's **Use cases** tab: open a case there to try it
on your phone.

## Scanning

### A scan button

One code, then back to your screen.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=scan_button){target="_self"}

::: details scan_button.dart

<<< @/../example/lib/use_cases/scan_button.dart

:::

### Your brand’s look

Your colors, buttons, scan window, texts and widgets.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=custom_look){target="_self"}

::: details custom_look.dart

<<< @/../example/lib/use_cases/custom_look.dart

:::

### Buttons of your own

Your buttons under the scan window, the built-in ones moved.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=own_buttons){target="_self"}

::: details own_buttons.dart

<<< @/../example/lib/use_cases/own_buttons.dart

:::

### Scan into a form

A serial number, IMEI or tracking number into a text field.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=scan_into_form){target="_self"}

::: details scan_into_form.dart

<<< @/../example/lib/use_cases/scan_into_form.dart

:::

### Sign in on another screen

Your TV or web app shows a QR code, the phone confirms.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=sign_in_with_qr){target="_self"}

::: details sign_in_with_qr.dart

<<< @/../example/lib/use_cases/sign_in_with_qr.dart

:::

### Open a link safely

Show where a QR code leads before opening it.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=open_link){target="_self"}

::: details open_link.dart

<<< @/../example/lib/use_cases/open_link.dart

:::

### Wi‑Fi from a QR code

The network and its password, copied in a tap.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=join_wifi){target="_self"}

::: details join_wifi.dart

<<< @/../example/lib/use_cases/join_wifi.dart

:::

### Pay by QR code

SEPA, Swiss QR-bill, UPI, PIX... into your payment screen.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=pay_by_qr){target="_self"}

::: details pay_by_qr.dart

<<< @/../example/lib/use_cases/pay_by_qr.dart

:::

### Look up a product

EAN, UPC or ISBN into your catalogue.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=product_lookup){target="_self"}

::: details product_lookup.dart

<<< @/../example/lib/use_cases/product_lookup.dart

:::

### Boarding pass

Passenger, flight and seat from the pass.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=boarding_pass){target="_self"}

::: details boarding_pass.dart

<<< @/../example/lib/use_cases/boarding_pass.dart

:::

### Tickets at the door

Each ticket checked against the guest list, nonstop.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=door_check_in){target="_self"}

::: details door_check_in.dart

<<< @/../example/lib/use_cases/door_check_in.dart

:::

### Stocktake

Many barcodes in a row, with counts.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=stocktake){target="_self"}

::: details stocktake.dart

<<< @/../example/lib/use_cases/stocktake.dart

:::

### Receive parcels

GS1-128 shipping labels: SSCC, GTIN, quantity, batch.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=parcels){target="_self"}

::: details parcels.dart

<<< @/../example/lib/use_cases/parcels.dart

:::

### Loyalty card at the till

The card number from its barcode, large.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=loyalty_card){target="_self"}

::: details loyalty_card.dart

<<< @/../example/lib/use_cases/loyalty_card.dart

:::

### Medicine pack

Batch, serial and expiry from the Data Matrix.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=medicine_pack){target="_self"}

::: details medicine_pack.dart

<<< @/../example/lib/use_cases/medicine_pack.dart

:::

### Vehicle VIN

The maker and model year from the windshield code.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=vin){target="_self"}

::: details vin.dart

<<< @/../example/lib/use_cases/vin.dart

:::

### Self-service kiosk

The front camera, large text, no buttons.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=kiosk){target="_self"}

::: details kiosk.dart

<<< @/../example/lib/use_cases/kiosk.dart

:::

### Pick one of many

Several codes in view, tap the one you need.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=pick_one){target="_self"}

::: details pick_one.dart

<<< @/../example/lib/use_cases/pick_one.dart

:::

### Read from a photo

A screenshot or a picture from the gallery.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=read_from_photo){target="_self"}

::: details read_from_photo.dart

<<< @/../example/lib/use_cases/read_from_photo.dart

:::

### Add a 2FA account

An otpauth:// code into your authenticator.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=add_2fa){target="_self"}

::: details add_2fa.dart

<<< @/../example/lib/use_cases/add_2fa.dart

:::

## Creating codes

### My profile QR code

A styled QR code of a profile link, shared as an image.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=profile_qr){target="_self"}

::: details profile_qr.dart

<<< @/../example/lib/use_cases/profile_qr.dart

:::

### A ticket in the app

A ticket card with the code the door scans.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=ticket_card){target="_self"}

::: details ticket_card.dart

<<< @/../example/lib/use_cases/ticket_card.dart

:::

### Wi‑Fi card for guests

A QR code that joins the network, to print or share.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=wifi_for_guests){target="_self"}

::: details wifi_for_guests.dart

<<< @/../example/lib/use_cases/wifi_for_guests.dart

:::

### A QR code on an invoice

A SEPA or Swiss QR-bill payment code.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=invoice_qr){target="_self"}

::: details invoice_qr.dart

<<< @/../example/lib/use_cases/invoice_qr.dart

:::

### A sheet of labels

Many codes on an A4 page in columns, as SVG for print.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=label_sheet){target="_self"}

::: details label_sheet.dart

<<< @/../example/lib/use_cases/label_sheet.dart

:::

### Business card

A vCard QR code that saves your contact.

[Try it in the demo](https://khoren93.github.io/flutter_zxing/demo/?case=business_card){target="_self"}

::: details business_card.dart

<<< @/../example/lib/use_cases/business_card.dart

:::
