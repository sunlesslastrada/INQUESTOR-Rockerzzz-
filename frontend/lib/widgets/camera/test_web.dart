// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void test() {
  ui_web.platformViewRegistry.registerViewFactory('test-view', (int viewId) {
    return html.DivElement();
  });
}
