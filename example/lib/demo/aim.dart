// The symbology identifier a scanner sends before the data (ISO/IEC 15424,
// "AIM ID"), in words: `]Q3` is a QR Code, Model 2, with GS1 data.

/// An AIM ID taken apart.
typedef AimParts = ({String symbology, String modifier});

/// [id] (`]d2`) in words, or `null` if it is not an AIM ID.
AimParts? describeAim(String id) {
  if (id.length < 3 || id[0] != ']') {
    return null;
  }
  final String code = id[1];
  final String m = id.substring(2);
  final String? symbology = _symbologies[code];
  if (symbology == null) {
    return (symbology: 'Symbology “$code”', modifier: 'Modifier $m');
  }
  return (
    symbology: symbology,
    modifier: _modifiers[code]?[m] ?? (m == '0' ? 'Standard' : 'Modifier $m'),
  );
}

const Map<String, String> _symbologies = <String, String>{
  'A': 'Code 39',
  'B': 'Telepen',
  'C': 'Code 128',
  'D': 'Code One',
  'E': 'EAN / UPC',
  'F': 'Codabar',
  'G': 'Code 93',
  'H': 'Code 11',
  'I': 'Interleaved 2 of 5',
  'J': 'DotCode',
  'K': 'Code 16K',
  'L': 'PDF417',
  'M': 'MSI',
  'N': 'Anker',
  'O': 'Codablock',
  'P': 'Plessey',
  'Q': 'QR Code',
  'R': 'Straight 2 of 5, two bars',
  'S': 'Straight 2 of 5, three bars',
  'T': 'Code 49',
  'U': 'MaxiCode',
  'X': 'Other symbology',
  'd': 'Data Matrix',
  'e': 'GS1 DataBar',
  'h': 'Han Xin',
  'z': 'Aztec',
};

/// What the modifier character means, by symbology.
const Map<String, Map<String, String>> _modifiers =
    <String, Map<String, String>>{
      'A': <String, String>{
        '0': 'No check digit',
        '1': 'Check digit checked and sent',
        '3': 'Check digit checked and removed',
        '4': 'Full ASCII, no check digit',
        '5': 'Full ASCII, check digit checked and sent',
        '7': 'Full ASCII, check digit checked and removed',
      },
      'B': <String, String>{
        '0': 'Full ASCII',
        '1': 'Double-density numeric',
        '2': 'Numeric, then full ASCII',
        '4': 'Full ASCII, then numeric',
      },
      'C': <String, String>{
        '0': 'Standard',
        '1': 'GS1-128: FNC1 in first position',
        '2': 'FNC1 in second position',
        '4': 'ISBT 128 concatenation',
      },
      'E': <String, String>{
        '0': 'EAN-13, UPC-A or UPC-E',
        '1': 'Two-digit add-on only',
        '2': 'Five-digit add-on only',
        '3': 'EAN-13, UPC-A or UPC-E with its add-on',
        '4': 'EAN-8',
      },
      'F': <String, String>{
        '0': 'Standard',
        '1': 'ABC Codabar',
        '2': 'Check digit checked and removed',
        '4': 'Check digit checked and sent',
      },
      'H': <String, String>{
        '0': 'One check digit',
        '1': 'Two check digits',
        '3': 'Check digits checked and removed',
      },
      'I': <String, String>{
        '0': 'No check digit',
        '1': 'Check digit checked and sent',
        '3': 'Check digit checked and removed',
      },
      'L': <String, String>{
        '0': 'Standard, with backslashes doubled',
        '1': 'ECI protocol',
        '2': 'Basic channel, no ECI',
      },
      'Q': <String, String>{
        '0': 'Model 1',
        '1': 'Model 2',
        '2': 'Model 2, ECI protocol',
        '3': 'Model 2, GS1: FNC1 in first position',
        '4': 'Model 2, GS1 with ECI',
        '5': 'Model 2, FNC1 in second position',
        '6': 'Model 2, FNC1 in second position, ECI',
      },
      'U': <String, String>{
        '0': 'Mode 4 or 5',
        '1': 'Mode 2 or 3',
        '2': 'Mode 4 or 5, ECI protocol',
        '3': 'Mode 2 or 3, ECI protocol',
      },
      'd': <String, String>{
        '0': 'ECC 000–140',
        '1': 'ECC 200',
        '2': 'ECC 200, GS1: FNC1 in first position',
        '3': 'ECC 200, FNC1 in second position',
        '4': 'ECC 200, ECI protocol',
        '5': 'ECC 200, GS1 with ECI',
        '6': 'ECC 200, FNC1 in second position, ECI',
      },
      'e': <String, String>{'0': 'GS1 data'},
      'h': <String, String>{'0': 'Standard', '1': 'ECI protocol'},
      'z': <String, String>{
        '0': 'Standard',
        '1': 'GS1: FNC1 in first position',
        '2': 'FNC1 in second position',
        '3': 'ECI protocol',
        '4': 'GS1 with ECI',
        '5': 'FNC1 in second position, ECI',
        '6': 'Structured append',
        'C': 'Aztec Rune',
      },
    };
