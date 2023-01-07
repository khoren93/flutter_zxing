// Contains the messages used in the app
class Messages {
  const Messages({
    this.createButton = 'Create',
    this.textLabel = 'Enter barcode text here',
    this.formatLabel = 'Format',
    this.marginLabel = 'Margin',
    this.eccLevelLabel = 'ECC Level',
    this.widthLabel = 'Width',
    this.heightLabel = 'Height',
    this.lowEccLevel = 'Low (7%)',
    this.mediumEccLevel = 'Medium (15%)',
    this.quartileEccLevel = 'Quartile (25%)',
    this.highEccLevel = 'High (30%)',
    this.invalidText = 'Please enter some text',
    this.invalidWidth = 'Invalid width',
    this.invalidHeight = 'Invalid height',
    this.invalidMargin = 'Invalid margin',
  });

  final String createButton;

  final String textLabel;
  final String formatLabel;
  final String marginLabel;
  final String eccLevelLabel;
  final String widthLabel;
  final String heightLabel;

  final String lowEccLevel;
  final String mediumEccLevel;
  final String quartileEccLevel;
  final String highEccLevel;

  final String invalidText;
  final String invalidWidth;
  final String invalidHeight;
  final String invalidMargin;
}
