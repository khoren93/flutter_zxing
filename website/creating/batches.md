# Many codes

A [label sheet](./label-sheets) or a batch export takes a list of items,
one code each. Three helpers make that list: `SerialItems` numbers items
from a pattern, `BarcodeItems` reads them from pasted text or a CSV file,
and `CheckDigit` adds check digits. `BarcodeWriter.checkItems` finds an
item that will not encode before a long export stops halfway.

## Numbered items

`SerialItems` makes items from a pattern with one placeholder for the
number: `{n}`, or `{n:6}` to pad it with zeros to 6 digits.

```dart
Future<Uint8List> boxLabels() {
  final SerialItems items = SerialItems('BOX-{n:6}', count: 10000);
  // BOX-000001, BOX-000002, ... BOX-010000
  const sheet = BarcodeLabelSheet(columns: 3, rows: 8);
  return sheet.pdf(items);
}
```

| Setting | Default | What it is |
|---|---|---|
| `pattern` | required | Text with `{n}` or `{n:W}` where the number goes; a brace written twice for a literal one |
| `count` | required | How many items |
| `start` | `1` | The first number |
| `step` | `1` | What each number adds; negative counts down |
| `checkDigit` | none | A check character appended to each item |

The items are made one at a time when they are asked for, so 10 000 or 10
million take no memory, and `length`, `items[i]` and `elementAt` are
instant: the sheet's `pageCount(items.length)` and its progress cost
nothing. It is a read-only `List<String>`.

A number wider than its padding keeps all its digits: `{n:3}` gives `999`,
then `1000`. Numbers go up to 2^53 - 1 (16 digits), the largest whole
number exact on the web; put a longer fixed part, such as a company
prefix, in the pattern's text. The constructor throws `ArgumentError` for
a pattern without a placeholder or with two, a count of 0, a step of 0 or
numbers that would go below 0.

## Check digits

`CheckDigit.gs1` is the mod 10 check digit of GTIN (EAN-13, EAN-8, UPC-A,
GTIN-14), SSCC and GLN; `CheckDigit.luhn` that of card, IMEI and many
account numbers; `CheckDigit.mod43` the Code 39 check character.

```dart
void checkDigits() {
  print(CheckDigit.gs1.of('400638133393')); // 1
  print(CheckDigit.gs1.append('400638133393')); // 4006381333931
  print(CheckDigit.gs1.isValid('4006381333931')); // true
  print(CheckDigit.luhn.of('7992739871')); // 3
}
```

With `SerialItems` the check digit is computed over the whole item, the
pattern's text and the number, so a GS1 or Luhn pattern has digits only:

```dart
// SSCCs of company prefix 0614141: extension digit 1, a 9-digit serial.
final SerialItems ssccs = SerialItems(
  '10614141{n:9}',
  start: 1,
  count: 500,
  checkDigit: CheckDigit.gs1,
);
```

EAN-13, EAN-8, UPC-A, UPC-E and GS1 DataBar add their check digit
themselves: give them 12 digits (7 for EAN-8, 11 for UPC-A) and leave
`checkDigit` out, or give the full number with the right digit.

## Lists and CSV files

`BarcodeItems.lines` takes one item a line, for text pasted into a field;
`BarcodeItems.csv` one column of a CSV file. Both trim the items and
leave empty ones out; `unique: true` leaves out repeats too.

```dart
Future<BarcodeItems> fromFile(File file) async {
  final String csv = await file.readAsString();
  final List<String> columns = BarcodeItems.csvHeaders(csv);
  // Show `columns` in a picker; here, the column called EAN.
  return BarcodeItems.csv(csv, column: columns.indexOf('EAN'), header: true);
}
```

The CSV is read as Excel and RFC 4180 write it: a cell in double quotes
may hold the separator, line breaks and quotes written twice (`""`); rows
end with `\n`, `\r\n` or `\r`; a byte order mark at the start is skipped.
Without a `separator` the one the first row has most of among `,`, `;`
and tab is taken: Excel saves CSV with `;` in many countries. Rows
without the column are left out. `BarcodeItems.csvRows` gives the rows
themselves, for a preview table.

## Check before a long export

A label sheet stops at the first item it cannot encode.
`BarcodeWriter.checkItems` finds that item first, so a form can say which
one and why:

```dart
Future<String?> problem(List<String> items) async {
  const writer = BarcodeWriter(BarcodeFormat.ean13);
  final BarcodeItemIssue? issue = await writer.checkItems(items);
  if (issue == null) {
    return null;
  }
  // Item 36 ("AB-1"): 'A' at position 1: EAN-13 takes digits only, ...
  return 'Row ${issue.index + 1} (${issue.item}): ${issue.message}';
}
```

It checks every item against the simple rules of the format, which is
quick for 100 000 items: empty items, characters the format does not take
(letters in an EAN-13, `é` in Code 39, `€` in Code 128), too many digits
and a wrong check digit for EAN, UPC and GS1 DataBar, the start and stop
letters of Codabar. Then it encodes the first, the last and the longest
item, which finds an item too long for a QR code in most lists. Rarer
rules, such as an ISBN's check digit, only show when the item is encoded:
`encodeAll: true` encodes every item, which is exact and as slow as the
export itself.
