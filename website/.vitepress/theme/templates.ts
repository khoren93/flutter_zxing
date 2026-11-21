// The scanner templates, for the gallery and the home page. `shot` is the
// file test/tool/scanner_shots_test.dart renders into public/shots/
// (`make site-shots`); `demo` is the template's name in the demo app.
export interface Template {
  name: string
  ctor: string
  shot: string
  demo: string
  forWhat: string
}

export const templates: Template[] = [
  {
    name: 'Minimal',
    ctor: 'ScannerTemplate.minimal()',
    shot: 'minimal-locked',
    demo: 'minimal',
    forWhat: 'Any code, with a sheet that shows what is in it; the default of scanBarcode.',
  },
  {
    name: 'Payment',
    ctor: 'ScannerTemplate.payment()',
    shot: 'payment',
    demo: 'payment',
    forWhat: 'Paying with a QR code: the window high up, your payment sheet below.',
  },
  {
    name: 'Retail',
    ctor: 'ScannerTemplate.retail()',
    shot: 'retail',
    demo: 'retail',
    forWhat: 'Product and shipping barcodes in a row: dark glass, the torch, a list with counts.',
  },
  {
    name: 'Ticket',
    ctor: 'ScannerTemplate.ticket()',
    shot: 'ticket',
    demo: 'ticket',
    forWhat: 'Boarding passes, tickets and IDs (PDF417, Aztec, QR, Data Matrix), your sheet with the fields.',
  },
  {
    name: 'Content',
    ctor: 'ScannerTemplate.content()',
    shot: 'content',
    demo: 'content',
    forWhat: 'Everyday QR codes (links, Wi-Fi, contacts, events): dark glass, your actions such as Open or Connect.',
  },
  {
    name: 'Product',
    ctor: 'ScannerTemplate.product()',
    shot: 'product',
    demo: 'product',
    forWhat: 'Products and books: EAN and UPC, a sheet with the GTIN or ISBN.',
  },
  {
    name: 'Small',
    ctor: 'ScannerTemplate.small()',
    shot: 'small',
    demo: 'small',
    forWhat: 'Small codes on parts and boards: a small window, 2× zoom from the start.',
  },
  {
    name: 'Sign-in',
    ctor: 'ScannerTemplate.signIn()',
    shot: 'sign-in',
    demo: 'signIn',
    forWhat: 'Signing in or pairing with a QR code on another screen: closes with the code accepted.',
  },
  {
    name: 'Check-in',
    ctor: 'ScannerTemplate.checkIn(check: ...)',
    shot: 'check-in-ok',
    demo: 'checkIn',
    forWhat: 'Tickets at the door: scanning never stops, a green, amber or red verdict for each code, a counter.',
  },
  {
    name: 'Pharma',
    ctor: 'ScannerTemplate.pharma()',
    shot: 'pharma',
    demo: 'pharma',
    forWhat: 'Medicine packs: GS1 Data Matrix with the GTIN, batch, serial and expiry date, marked when expired.',
  },
  {
    name: 'Pick',
    ctor: 'ScannerTemplate.pick()',
    shot: 'pick',
    demo: 'pick',
    forWhat: 'Several codes in view or on a photo: no window, a label on every code, a tap picks one.',
  },
  {
    name: 'Logistics',
    ctor: 'ScannerTemplate.logistics()',
    shot: 'logistics',
    demo: 'logistics',
    forWhat: 'Shipping labels: GS1-128 with SSCC, GTIN, quantity and batch in a list.',
  },
  {
    name: 'Kiosk',
    ctor: 'ScannerTemplate.kiosk()',
    shot: 'kiosk',
    demo: 'kiosk',
    forWhat: 'Self-service: the front camera, no buttons, large text, verdicts that hide by themselves.',
  },
  {
    name: 'Fullscreen',
    ctor: 'ScannerTemplate.fullscreen()',
    shot: 'fullscreen-locked',
    demo: 'fullscreen',
    forWhat: 'The whole camera without a window: the brackets appear on the code.',
  },
  {
    name: 'VIN',
    ctor: 'ScannerTemplate.vin()',
    shot: 'vin',
    demo: 'vin',
    forWhat: 'Vehicle identification numbers on the windshield or the door pillar.',
  },
  {
    name: 'Loyalty',
    ctor: 'ScannerTemplate.loyalty()',
    shot: 'loyalty',
    demo: 'loyalty',
    forWhat: 'Loyalty and membership cards: the card number large.',
  },
]
