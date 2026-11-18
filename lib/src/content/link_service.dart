import 'barcode_content.dart';

/// What [LinkService.link] takes for a service.
enum LinkServiceInput {
  /// A phone number with the country code: `+374 91 234567`.
  phone,

  /// A user name or handle, with or without `@`.
  username,

  /// An id the service gives out: an invite code, an app id, a package
  /// name, a place id, or a path such as `artist/0TnOYISbd1XYRBk9myaseg`.
  id,

  /// A place to search for: an address or a name.
  query,
}

/// Services with well-known links: messengers, social networks, music,
/// app stores and maps.
///
/// [link] builds a service's link from a phone number, user name or id,
/// and [UrlContent.service] recognises a scanned link's service, so that a
/// result screen can name it:
///
/// ```dart
/// final UrlContent chat = LinkService.whatsApp.link('+374 91 234567');
/// BarcodeView(chat.toPayload()); // https://wa.me/37491234567
///
/// LinkService.instagram.link('@flutter.dev').service; // instagram
/// ```
///
/// Links are plain `https://` addresses: any camera app opens them, in the
/// service's app if it is installed.
enum LinkService {
  /// WhatsApp chat (`wa.me`), optionally with a message.
  whatsApp('WhatsApp', LinkServiceInput.phone),

  /// Telegram user, channel or group (`t.me`).
  telegram('Telegram', LinkServiceInput.username),

  /// Signal chat (`signal.me`).
  signal('Signal', LinkServiceInput.phone),

  /// Instagram profile.
  instagram('Instagram', LinkServiceInput.username),

  /// Facebook profile or page.
  facebook('Facebook', LinkServiceInput.username),

  /// X (Twitter) profile.
  x('X', LinkServiceInput.username),

  /// LinkedIn profile (`linkedin.com/in/…`).
  linkedIn('LinkedIn', LinkServiceInput.username),

  /// TikTok profile.
  tikTok('TikTok', LinkServiceInput.username),

  /// YouTube channel (`youtube.com/@…`).
  youTube('YouTube', LinkServiceInput.username),

  /// Snapchat profile (`snapchat.com/add/…`).
  snapchat('Snapchat', LinkServiceInput.username),

  /// Pinterest profile.
  pinterest('Pinterest', LinkServiceInput.username),

  /// Threads profile.
  threads('Threads', LinkServiceInput.username),

  /// Discord invite (`discord.gg/…`).
  discord('Discord', LinkServiceInput.id),

  /// Twitch channel.
  twitch('Twitch', LinkServiceInput.username),

  /// Reddit user, or a community given as `r/name`.
  reddit('Reddit', LinkServiceInput.username),

  /// Spotify artist, album, track or playlist: `artist/…` or a
  /// `spotify:artist:…` URI.
  spotify('Spotify', LinkServiceInput.id),

  /// Apple Music page: the path after `music.apple.com/`.
  appleMusic('Apple Music', LinkServiceInput.id),

  /// SoundCloud profile.
  soundCloud('SoundCloud', LinkServiceInput.username),

  /// App Store app, by its numeric id.
  appStore('App Store', LinkServiceInput.id),

  /// Google Play app, by its package name.
  googlePlay('Google Play', LinkServiceInput.id),

  /// Google Maps search.
  googleMaps('Google Maps', LinkServiceInput.query),

  /// Apple Maps search.
  appleMaps('Apple Maps', LinkServiceInput.query),

  /// Yandex Maps search.
  yandexMaps('Yandex Maps', LinkServiceInput.query),

  /// The form for a Google review of a business, by its place id.
  googleReview('Google review', LinkServiceInput.id);

  const LinkService(this.displayName, this.input);

  /// The service's name, for labels.
  final String displayName;

  /// What [link] takes.
  final LinkServiceInput input;

  /// The link to [value] on this service: a phone number, user name, id or
  /// search, as [input] says. A whole `https://` link to this service is
  /// taken as it is. [message] pre-fills a WhatsApp chat.
  ///
  /// Throws an [ArgumentError] if [value] is empty or not a valid [input],
  /// or if [message] is given for another service.
  UrlContent link(String value, {String? message}) {
    if (message != null && this != whatsApp) {
      throw ArgumentError.value(message, 'message', 'Only WhatsApp takes one');
    }
    final String v = value.trim();
    final Uri? whole = Uri.tryParse(v);
    if (whole != null &&
        (whole.scheme == 'https' || whole.scheme == 'http') &&
        linkServiceOf(whole) == this) {
      return UrlContent(whole);
    }
    return UrlContent(Uri.parse(_url(_argument(v), message)));
  }

  String _argument(String v) {
    switch (input) {
      case LinkServiceInput.phone:
        final String digits = v.replaceAll(RegExp(r'[\s\-.()/]'), '');
        if (!RegExp(r'^\+?\d{4,15}$').hasMatch(digits)) {
          throw ArgumentError.value(v, 'value', 'Not a phone number');
        }
        return digits.startsWith('+') ? digits.substring(1) : digits;
      case LinkServiceInput.username || LinkServiceInput.id:
        String id = v.startsWith('@') ? v.substring(1) : v;
        id = id.replaceFirst(RegExp(r'/+$'), '');
        if (id.isEmpty || id.contains(RegExp(r'[\s?#]'))) {
          throw ArgumentError.value(v, 'value', 'Not a ${input.name}');
        }
        if (this == appStore && !RegExp(r'^(id)?\d+$').hasMatch(id)) {
          throw ArgumentError.value(v, 'value', 'Not an App Store id');
        }
        return id;
      case LinkServiceInput.query:
        if (v.isEmpty) {
          throw ArgumentError.value(v, 'value', 'Search is empty');
        }
        return v;
    }
  }

  String _url(String a, String? message) {
    String path(String id) => id.split('/').map(Uri.encodeComponent).join('/');
    final String q = Uri.encodeQueryComponent(a);
    final String u = Uri.encodeComponent(a);
    return switch (this) {
      whatsApp =>
        'https://wa.me/$a'
            '${message == null || message.isEmpty ? '' : '?text=${Uri.encodeQueryComponent(message)}'}',
      telegram => 'https://t.me/$u',
      signal => 'https://signal.me/#p/+$a',
      instagram => 'https://www.instagram.com/$u',
      facebook => 'https://www.facebook.com/$u',
      x => 'https://x.com/$u',
      linkedIn => 'https://www.linkedin.com/in/$u',
      tikTok => 'https://www.tiktok.com/@$u',
      youTube => 'https://www.youtube.com/@$u',
      snapchat => 'https://www.snapchat.com/add/$u',
      pinterest => 'https://www.pinterest.com/$u',
      threads => 'https://www.threads.net/@$u',
      discord => 'https://discord.gg/$u',
      twitch => 'https://www.twitch.tv/$u',
      reddit =>
        RegExp('^(r|u|user)/').hasMatch(a)
            ? 'https://www.reddit.com/${path(a)}'
            : 'https://www.reddit.com/user/$u',
      spotify =>
        'https://open.spotify.com/'
            '${path(a.replaceFirst(RegExp('^spotify:'), '').replaceAll(':', '/'))}',
      appleMusic => 'https://music.apple.com/${path(a)}',
      soundCloud => 'https://soundcloud.com/$u',
      appStore =>
        'https://apps.apple.com/app/id${a.replaceFirst(RegExp('^id'), '')}',
      googlePlay => 'https://play.google.com/store/apps/details?id=$q',
      googleMaps => 'https://www.google.com/maps/search/?api=1&query=$q',
      appleMaps => 'https://maps.apple.com/?q=$q',
      yandexMaps => 'https://yandex.com/maps/?text=$q',
      googleReview => 'https://search.google.com/local/writereview?placeid=$q',
    };
  }
}

/// [UrlContent.service]: the service [url] belongs to, by its host (and
/// path, for hosts that serve several services).
LinkService? linkServiceOf(Uri url) {
  if (url.scheme != 'http' && url.scheme != 'https') {
    return null;
  }
  final String host = url.host.toLowerCase().replaceFirst(
    RegExp(r'^(www|m|mobile)\.'),
    '',
  );
  final String path = url.path.toLowerCase();
  bool on(String domain) => host == domain || host.endsWith('.$domain');
  // google.com, google.de, google.co.uk, but not google.evil.com.
  final bool google = RegExp(
    r'^google\.(?:com|[a-z]{2}|com?\.[a-z]{2})$',
  ).hasMatch(host);
  final bool yandex = RegExp(
    r'^(maps\.)?yandex\.(?:com|[a-z]{2}|com\.[a-z]{2})$',
  ).hasMatch(host);
  if ((host == 'search.google.com' && path.startsWith('/local/writereview')) ||
      (host == 'g.page' && path.contains('/review'))) {
    return LinkService.googleReview;
  }
  if (host == 'maps.google.com' ||
      host == 'maps.app.goo.gl' ||
      (host == 'goo.gl' && path.startsWith('/maps')) ||
      (google && path.startsWith('/maps'))) {
    return LinkService.googleMaps;
  }
  if (yandex && (host.startsWith('maps.') || path.startsWith('/maps'))) {
    return LinkService.yandexMaps;
  }
  if (host == 'maps.apple.com') {
    return LinkService.appleMaps;
  }
  if (host == 'music.apple.com') {
    return LinkService.appleMusic;
  }
  if (host == 'apps.apple.com' || host == 'itunes.apple.com') {
    return LinkService.appStore;
  }
  if (host == 'play.google.com' && path.startsWith('/store')) {
    return LinkService.googlePlay;
  }
  for (final (LinkService service, List<String> domains) in _domains) {
    if (domains.any(on)) {
      return service;
    }
  }
  return null;
}

const List<(LinkService, List<String>)> _domains =
    <(LinkService, List<String>)>[
      (LinkService.whatsApp, <String>['wa.me', 'whatsapp.com']),
      (LinkService.telegram, <String>['t.me', 'telegram.me', 'telegram.dog']),
      (LinkService.signal, <String>['signal.me', 'signal.group']),
      (LinkService.instagram, <String>['instagram.com', 'instagr.am']),
      (
        LinkService.facebook,
        <String>['facebook.com', 'fb.com', 'fb.me', 'fb.watch'],
      ),
      (LinkService.x, <String>['x.com', 'twitter.com']),
      (LinkService.linkedIn, <String>['linkedin.com', 'lnkd.in']),
      (LinkService.tikTok, <String>['tiktok.com']),
      (LinkService.youTube, <String>['youtube.com', 'youtu.be']),
      (LinkService.snapchat, <String>['snapchat.com']),
      (LinkService.pinterest, <String>['pinterest.com', 'pin.it']),
      (LinkService.threads, <String>['threads.net', 'threads.com']),
      (
        LinkService.discord,
        <String>['discord.gg', 'discord.com', 'discordapp.com'],
      ),
      (LinkService.twitch, <String>['twitch.tv']),
      (LinkService.reddit, <String>['reddit.com', 'redd.it']),
      (LinkService.spotify, <String>['spotify.com', 'spotify.link']),
      (LinkService.soundCloud, <String>['soundcloud.com']),
    ];
