/// Barcode payloads as typed values: `barcode.content` parses a URL, a
/// Wi-Fi network, a contact, an event, GS1 data and so on.
///
/// A layer on top of `core.dart`, which it exports too.
library;

export 'core.dart';
export 'src/content/barcode_content.dart';
export 'src/content/content_writer.dart';
export 'src/content/link_service.dart' show LinkService, LinkServiceInput;
