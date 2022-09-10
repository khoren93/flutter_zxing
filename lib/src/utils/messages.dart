class Messages {
  const Messages({
    this.createButton = 'Create',
    this.textLabel = 'Enter barcode text here',
    this.marginLabel = 'Margin',
    this.eccLevelLabel = 'ECC Level',
    this.widthLabel = 'Width',
    this.heightLabel = 'Height',
    this.invalidText = 'Please enter some text',
    this.invalidWidth = 'Invalid width',
    this.invalidHeight = 'Invalid height',
    this.invalidMargin = 'Invalid margin',
    this.invalidEccLevel = 'Invalid ECC level',
  });

  final String createButton;

  final String textLabel;
  final String marginLabel;
  final String eccLevelLabel;
  final String widthLabel;
  final String heightLabel;

  final String invalidText;
  final String invalidWidth;
  final String invalidHeight;
  final String invalidMargin;
  final String invalidEccLevel;
}
