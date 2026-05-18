package net.attrx.yse_flutter_libs

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Empty Flutter plugin. Exists so the Flutter tool recognises this package as
 * an Android plugin and links the bundled native libraries (libyse.so per
 * ABI) into the host APK / AAB. No method channels — package:yse talks to
 * the engine directly via dart:ffi.
 */
class YseFlutterLibsPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
