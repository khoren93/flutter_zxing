// Boarding pass: the passenger and each flight (from, to, flight, date,
// seat) from the PDF417 or Aztec code of a paper or mobile boarding pass,
// for a travel or lounge app. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class BoardingPassPage extends StatelessWidget {
  const BoardingPassPage({super.key});

  // Tickets and other codes keep the scanner open.
  static final ScannerCheck _check = acceptOnly<BoardingPassContent>(
    reject: const ScanVerdict.reject(title: 'Not a boarding pass'),
  );

  static Widget? _sheet(BuildContext context, ScannerResult result) {
    final BarcodeContent content = result.barcode.content;
    // Anything else, such as a code from a photo: the default sheet.
    if (content is! BoardingPassContent) return null;
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = ScannerStrings.of(context);
    return ScannerSheet(
      label: 'Boarding pass',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // As printed: SURNAME/GIVEN NAMES.
          Text(content.passengerName, style: theme.overlineStyle),
          // One block per flight: a pass with a connection has two.
          for (final BoardingPassLeg leg in content.legs) ...[
            const SizedBox(height: 12),
            Text('${leg.from} → ${leg.to}', style: theme.titleStyle),
            const SizedBox(height: 8),
            ScannerFields({
              'Flight': '${leg.carrier} ${leg.flightNumber}',
              // The pass gives the day of the year, not the year.
              if (leg.date() case final DateTime day)
                'Date': strings.dayAndMonth(day),
              'Seat': leg.seat.isEmpty ? '–' : leg.seat,
              'Class': leg.cabin,
              'Booking': leg.bookingReference,
            }),
          ],
          const SizedBox(height: 16),
          ScannerActions([
            ScannerAction(
              label: 'Add to my trips',
              primary: true,
              onPressed: () {
                // Your code: save the pass to the user's trips.
                result.finish();
              },
            ),
            ScannerAction.scanAgain(result.scanAgain),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.ticket(
        title: 'Scan your boarding pass',
        check: _check,
        resultBuilder: _sheet,
      ),
    ),
  );
}
