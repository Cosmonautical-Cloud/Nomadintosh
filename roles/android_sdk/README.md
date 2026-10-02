# android_sdk

Sets up an Android SDK for headless builds: a JDK, the SDK command-line tools, accepted licenses, and an optional pre-installed package list.

Enabled per host or group with `android_sdk.enabled: true`.

## What it does

1. Installs `android_sdk_jdk_formula` (`openjdk@17`) and asserts `android_sdk_java_home` exists. It's keg-only — point anything else that needs it (Gradle, a CI runner) at `android_sdk_java_home`.
2. If `android_sdk_root` has no `cmdline-tools/latest`, unpacks Google's standalone command-line tools once and uses them to install `cmdline-tools;latest` into the root.
3. Accepts all SDK licenses. This is what lets Gradle and other sdkmanager-driven tooling download missing packages on their own at build time.
4. Installs whichever `android_sdk_packages` aren't already installed (diffed against `sdkmanager --list_installed`, so a run with nothing missing reports no change).

## Variables

| Variable | Default | Description |
|---|---|---|
| `android_sdk.enabled` | _(absent)_ | `true` runs the role |
| `android_sdk_root` | `/Users/{{ ansible_user }}/Library/Android/sdk` | Android Studio's default location |
| `android_sdk_packages` | `[]` | sdkmanager package paths to pre-install, e.g. `platforms;android-37.0`, `ndk;27.1.12297006`, `system-images;android-34;google_apis;arm64-v8a` |
| `android_sdk_jdk_formula` | `openjdk@17` | JDK formula |
| `android_sdk_java_home` | `{{ homebrew_dir }}/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` | Asserted to exist after install |
| `android_sdk_cmdline_tools_bootstrap_url` | Google's macOS command-line tools archive | Only used when the root has no `cmdline-tools` |

Packages are only ever added, never removed. `cmdline-tools` isn't listed in `android_sdk_packages` — sdkmanager doesn't report itself in `--list_installed`, so it would look missing on every run; step 2 covers it.
