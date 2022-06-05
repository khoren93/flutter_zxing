import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:zxscanner/configs/constants.dart';
import 'package:zxscanner/widgets/common_widgets.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help'),
      ),
      body: ContainerX(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(spaceDefault),
              child: InkWell(
                onTap: () {
                  launchUrlString('https://scanbot.io');
                },
                child: Column(
                  children: const [
                    Text('All information is taken from'),
                    Text('scanbot.io',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: spaceLarge2),
                children: createSlides(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget createSlide(
    BuildContext context, {
    String? title,
    String? body,
  }) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            title: Text(title ?? ''),
            children: [
              Padding(
                padding: const EdgeInsets.all(spaceDefault),
                child: MarkdownBody(data: body ?? ''),
              ),
            ],
          ),
        ),
      ),
    );
  }

  createSlides(BuildContext context) {
    return [
      createSlide(
        context,
        title: 'QR Code',
        body: """
QR codes are highly versatile and cover a range of applications because they store a large amount of information in a relatively small area. They are particularly popular in advertising, such as on flyers or shop windows, in public transport and airline ticketing, and in parcel delivery.
* Defined in the ISO/IEC 18004:2006 and JIS X0510 standards.
* 2D barcode that stores a maximum of 7089 digits or 4296 alphanumeric characters.
* Can be used free of charge – specifications are available from the Swiss-based International Organization for Standardization.
* Automatic error correction recovers damage to up to 30%, depending on the correction level chosen.
        """,
      ),
      createSlide(
        context,
        title: 'DataMatrix',
        body: """
Due to its small size and large storage capacity, the Data Matrix code is most frequently used in the aerospace, automotive, and electronics sectors. Applied through permanent marking, the code can identify spare parts over their whole lifespan. It also has applications in healthcare and postal services.
* 2D barcode with L-shaped border and pixel matrix.
* Defined in the ISO/IEC 16022 standard.
* Stores up to 3116 numeric or 2335 alphanumeric characters.
* Smallest size: 2.5 mm x 2.5 mm, thus ideal for small units.
* Often engraved on items via Direct Part Marking (DPM).
* Readable even with low contrast.
        """,
      ),
      createSlide(
        context,
        title: 'Aztec',
        body: """
The transportation sector accounts for most Aztec Code use cases. Lufthansa airline tickets contain this code, as do Deutsche Bahn tickets. The International Union of Railways (UIC) has chosen the Aztec Code as its standard for ticketing. Additionally, Aztec Codes are used in the healthcare sector, notably on patient identification bracelets.
* Two-dimensional barcode, standardized in ISO/IEC 24778.
* Freely available under US patent number 5591956.
* Can store over 3,000 characters in up to 32 layers.
* Less widely used than QR and Data Matrix Codes.
* Enables both high data density and up to 95% error tolerance.
* Pattern resembles a top-down view of an Aztec pyramid
            """,
      ),
      createSlide(
        context,
        title: 'PDF417',
        body: """
Ticketing, travel, and logistics are some of the most common areas of application for PDF417 codes. They also find use in healthcare, warehousing, administration, and ID documents, in particular the US driver's license. Due to its high data density and customizable size, the PDF417 is one of the most versatile and widely used barcode types.
* A two-dimensional barcode that stores around 2725 numbers or 1850 alphanumeric characters.
* “PDF” is short for “Portable data file”.
* Defined in the ISO/IEC 15438 standard.
* High data density, yet with adjustable length and width.
* Striking redundancy: Up to 40% damage can be compensated.
        """,
      ),
      createSlide(
        context,
        title: 'UPCA, UPCE',
        body: """
The Universal Product Code (UPC) is perfect for retail, warehousing, and distribution. Stores or warehouses use it in combination with their databases to assign individual prices or quantities to the coded products. Since the price is explicitly not part of the barcode, retail stores can set prices independently using their checkout system.
* Exclusively used within North America.
* One-dimensional barcode that stores exactly 12 numeric characters, which form the Global Trade Item Number (GTIN).
* The low data density makes it inadequate for encoding complex data.
        """,
      ),
      createSlide(
        context,
        title: 'EAN8, EAN13',
        body: """
The most important areas of application for EAN codes are retail, distribution, and warehousing. The EAN – short for European Article Number – is used to identify individual products, which can then be linked to quantities or prices in the store’s database. Since they can only store a limited amount of data, EAN codes are not suitable for the kind of complex information seen in ticketing or parcel shipping.
* Used worldwide despite the name, except for North America, which uses the UPC standard.
* Stores either 13 or 8 digits (EAN-13 vs. EAN-8), which encode a GTIN (Global Trade Identification Number).
* The last digit is a mod10 checksum.
* EAN codes are defined as GS1 standards.
        """,
      ),
      createSlide(
        context,
        title: 'Code39',
        body: """
Unlike other common barcodes, Code 39 can also encode letters, which makes it indispensable in the industrial sector. A frequent use case is in factory automation in the automotive and electronics industries. In the US, it was standardized and adopted by the AIAG (Automotive Industry Action Group).
* One-dimensional barcode that encodes 43 characters: uppercase letters, numeric digits, and a number of special characters.
* Self-checking. However, a modulo 43 check digit is sometimes included.
* The low data density makes it unsuitable for tiny items.
* Standardized as ANSI MH 10.8 M-1983 and ANSI/AIM BC1/1995.
        """,
      ),
      createSlide(
        context,
        title: 'Code93',
        body: """
This barcode symbology can store alphanumeric characters. Its main user, Canada Post, encodes supplementary delivery information with it.
* One-dimensional barcode encoding 43 alphanumeric characters and 5 special characters.
* In Code 93 Extended, combinations of those characters can represent all 128 ASCII characters.
        """,
      ),
      createSlide(
        context,
        title: 'Code128',
        body: """
The Code 128 barcode is most frequently used in transporting goods, especially to mark containers for distribution, and warehousing. With it, various kinds of information about the respective goods can be flexibly encoded and read with a wide range of conventional scanners or smartphones. Its focus is clearly on non-POS areas. Check out our Barcode Scanner for logistics to learn more about possible application among the transportation area.
* A one-dimensional barcode defined in the ISO/IEC 15417 standard.
* Can encode all ASCII characters, including special characters.
* High data density compared to other 1D barcode formats.
        """,
      ),
      createSlide(
        context,
        title: 'CodaBar',
        body: """
The Codabar barcode is only used in blood banks, libraries, and in laboratories.
* 1D (linear) barcode type.
* Self-checking, with no need for a check digit.
* Encodes alphanumeric characters, as well as six special characters.
* Stores up to 16 characters.
* Newer barcode types can store more data in less space.
        """,
      ),
      createSlide(
        context,
        title: 'ITF',
        body: """
ITF barcodes are often described as Standard Distribution Codes. They are frequently found on cardboard boxes and other kinds of outer packaging.
* One-dimensional barcodes that encode two numerical characters for every five bars.
* High data density, as data is stored in both the bars and the gaps. 
* Compared to other linear barcodes, more data can be accommodated using the same label size.
        """,
      ),
    ];
  }
}

/*

DataBar

DataBarExpanded

MaxiCode

*/