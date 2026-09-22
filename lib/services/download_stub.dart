/// Used on Android/iOS, where file download is not available (the report is copied instead).
void downloadTextFile(String filename, String content) {
  throw UnsupportedError('Download is only available on the web');
}
