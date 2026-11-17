// The way to ZXScanner, the app built with flutter_zxing: off until it is
// in the stores.
import 'dart:async';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'content.dart';
import 'tokens.dart';

/// ZXScanner's page; `null` until the app is out. Setting it turns the card
/// into a link.
final Uri? zxScannerUrl = null;

/// "ZXScanner · Built with flutter_zxing", with "Soon" until it is out.
class BuiltWithCard extends StatelessWidget {
  const BuiltWithCard({super.key});

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final Uri? url = zxScannerUrl;
    final Widget body = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fz.ink,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.crop_free_rounded, size: 20, color: fz.raised),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'ZXScanner',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Built with flutter_zxing',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (url == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: fz.inkMuted.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SOON',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: fz.inkMuted,
                ),
              ),
            )
          else
            Icon(Icons.open_in_new_rounded, size: 18, color: fz.inkMuted),
        ],
      ),
    );
    return Semantics(
      button: url != null,
      child: Material(
        color: fz.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: fz.line),
        ),
        child: url == null
            ? body
            : InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => unawaited(openUri(context, url)),
                child: body,
              ),
      ),
    );
  }
}
