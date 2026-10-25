/// Catalog / media URL helpers for Supabase Storage.
///
/// Public assets (`/object/public/`) can be resized via `/render/image/public/`.
/// Private signed media (`/object/sign/…?token=`) must keep the query string —
/// stripping the token is what made generation results show broken icons.
class CatalogImages {
  CatalogImages._();

  static const _objectMarker = '/storage/v1/object/public/';
  static const _renderMarker = '/storage/v1/render/image/public/';
  static const _signMarker = '/storage/v1/object/sign/';
  static const _authMarker = '/storage/v1/object/authenticated/';

  /// Private media that requires a signed token (or auth header).
  static bool isSigned(String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.contains(_signMarker) || lower.contains(_authMarker)) {
      return true;
    }
    // Token query on a storage host — treat as signed.
    if (lower.contains('/storage/v1/') &&
        (lower.contains('token=') || lower.contains('?token'))) {
      return true;
    }
    return false;
  }

  /// True when [url] is a Supabase public object we can resize.
  static bool canOptimize(String? url) {
    if (url == null || url.isEmpty) return false;
    if (isSigned(url)) return false;
    return url.contains(_objectMarker) || url.contains(_renderMarker);
  }

  /// Stable object URL for public assets (strip render transform / cache bust).
  /// Signed URLs are returned unchanged so the auth token survives.
  static String? originalUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (isSigned(url)) return url;
    if (url.contains(_renderMarker)) {
      return url.split('?').first.replaceFirst(_renderMarker, _objectMarker);
    }
    return url.split('?').first;
  }

  /// Downscale via Supabase image render so multi‑MB PNGs don't stall the UI.
  /// Returns the URL as-is for signed / non-public hosts.
  static String? displayUrl(
    String? url, {
    int width = 720,
    int quality = 75,
  }) {
    if (url == null || url.isEmpty) return null;
    if (!canOptimize(url)) return url;

    final original = originalUrl(url);
    if (original == null || !original.contains(_objectMarker)) return url;

    final rendered = original.replaceFirst(_objectMarker, _renderMarker);
    return '$rendered?width=$width&quality=$quality&resize=contain';
  }
}
