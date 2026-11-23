# Payments

Every payment code is a `PaymentContent` with the same five questions
answered, whatever the country, and a kind per standard with its own
fields.

```dart
void pay(Barcode barcode) {
  if (barcode.content case final PaymentContent payment) {
    print(payment.payee); // Kaffeehaus Lumen
    print(payment.account); // the IBAN, account number, UPI ID or PIX key
    print(payment.amount); // 12.50, or null when the payer enters it
    print(payment.currency); // EUR
    print(payment.reference); // the payment reference, if any
  }
}
```

The amount is text in the currency's main unit with a decimal point
(`'12.50'` euros, not cents), so no cent is lost to a `double`. It is as
the code writes it: one code says `12.5`, another `12.50`, so compare
amounts as numbers. The currency is the ISO 4217 code, fixed by the
standard for EPC (`EUR`), ГОСТ (`RUB`) and UPI (`INR`).

A code whose IBAN, reference or checksum is wrong is not a payment: it
parses as `TextContent`.

<LiveDemo query="template=payment" shot="payment" label="The Payment template in the demo" />

## Standards

| Kind | Standard | Payload | Checks |
|---|---|---|---|
| `EpcPaymentContent` | EPC069-12 SEPA credit transfer ("GiroCode") | `BCD\n002\n1\nSCT\n…` | IBAN, BIC, RF reference, amount ≤ 999 999 999.99 EUR, 331 bytes |
| `SwissQrBillContent` | Swiss Payment Standards 2.3 | `SPC\n0200\n1\n…\nEPD` | IBAN or QR-IBAN, `creditorReference`: QR reference (mod 10) or RF, structured addresses, 997 characters |
| `GostPaymentContent` | ГОСТ Р 56042-2014 | `ST00012\|Name=…\|…` | account, BIC, correspondent account, INN, KPP; read in Windows-1251, UTF-8 and KOI8-R, written in UTF-8 |
| `UpiPaymentContent` | NPCI UPI | `upi://pay?pa=…` | UPI address, amount, INR |
| `EmvPaymentContent` | EMVCo merchant-presented QR: PIX, PayNow, PromptPay, QRIS, VietQR, DuitNow and others | `000201…6304XXXX` | CRC16; built with `EmvPaymentContent.pix(...)` |
| `SpaydPaymentContent` | Short Payment Descriptor (Czech Republic) | `SPD*1.0*ACC:…` | IBAN, BIC, symbols, `CRC32` when present |

PAY by square (Slovakia) is not supported yet: it is LZMA-compressed.

## Create a payment code

```dart
const epc = EpcPaymentContent(
  name: 'Kaffeehaus Lumen',
  iban: 'DE89370400440532013000',
  amount: '12.50',
  message: 'Invoice 42',
);

Widget giroCode() => BarcodeView(
  epc.toPayload(),
  writer: const BarcodeWriter(
    BarcodeFormat.qrCode,
    errorCorrection: ErrorCorrection.medium,
  ),
  width: 200,
);
```

`validate()` lists what keeps a payment from being built, such as a wrong
IBAN, before `toPayload()` would throw: see
[Building content](./building#forms).

`BarcodeContentView` draws a payment with what its standard requires: a
QR code with error correction M for EPC and the Swiss QR-bill, and the
Swiss cross in the middle of a QR-bill (`BarcodeStyle.swissQrBill`). A
payment that `validate()` finds problems in shows `errorBuilder` instead of
a code.

```dart
Widget bill(PaymentContent payment) => BarcodeContentView(
  payment,
  width: 200,
  errorBuilder: (BuildContext context, BarcodeWriteException error) =>
      Text(error.message),
);
```

`ScannerStrings.amount` writes an amount with its currency as the result
sheet does ("1949.75 EUR", "Any amount" without one); give your own to
format it for a locale.

```dart
Widget amount(BuildContext context, PaymentContent payment) => Text(
  ScannerStrings.of(context).amount(payment.amount, payment.currency),
);
```
