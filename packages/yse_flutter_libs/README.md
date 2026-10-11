# yse_flutter_libs (deprecated, not published)

> **Deprecated (#96).** [`package:yse`](https://pub.dev/packages/yse)
> bundles the engine for Flutter Android itself, through its native-assets
> build hook. Depend on `yse` alone:
>
> ```yaml
> dependencies:
>   yse: ^0.2.0
> ```
>
> This plugin is **not published to pub.dev** and will not be: it was never
> released there, pub.dev package names are permanent, and it no longer
> does anything. It stays in the dart-yse repository only so that apps
> which list it as a path or git dependency keep building.

## What changed

Up to 0.2.0 this plugin downloaded the engine's prebuilt Android release
(`libyse-<tag>-android.tar.gz`) in its Gradle build and added
`lib/arm64-v8a/libyse.so` and `lib/x86_64/libyse.so` to the app as
`jniLibs` (#91).

`package:yse` now does that itself (#96): its build hook downloads the same
release asset once per project, checks its sha256, and reports the target
ABI's `libyse.so` as a code asset. Flutter (3.38 or later) packages it
into the APK / AAB under `lib/<abi>/`, the same place the plugin put it.
If the plugin still added its copy, the app would carry two
`lib/<abi>/libyse.so` files and fail the native-library merge, so from
0.3.0 the plugin packages nothing: its `android/build.gradle` is an empty
Android library module.

## Migrating

1. Remove `yse_flutter_libs` from your app's `pubspec.yaml`.
2. Keep your app's `minSdk` at 26 or higher (the engine uses Oboe's AAudio
   backend; Flutter's template defaults lower). Up to 0.2.0 the plugin
   enforced that through the manifest merge; 0.3.0 declares no `minSdk`.
3. The Gradle properties the plugin read no longer do anything:
   - `yse.engineDir` (offline builds) and `yse.buildFromSource` /
     `yse.engineSourceDir` / `yse.abis` (an unreleased engine or 32-bit
     ABIs) are replaced by the build hook's `engine_dir` user-define, a
     folder laid out like an unpacked `libyse-<tag>-android` release
     (`lib/<abi>/libyse.so`). Set it in your app's `pubspec.yaml`:

     ```yaml
     hooks:
       user_defines:
         yse:
           engine_dir: /path/to/libyse-v3.1.0-android
     ```

     See the "Android" section of the `package:yse` README for building
     that folder from engine sources.

## License

Eclipse Public License 2.0 — matches the upstream engine and
`package:yse`.
