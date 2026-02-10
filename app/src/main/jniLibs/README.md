# Swift Native Libraries

This directory contains native libraries compiled from FoodshareCore using the Swift SDK for Android.

## Structure

```
jniLibs/
├── arm64-v8a/              # ARM64 (physical devices)
│   ├── libFoodshareCore.so # FoodshareCore Swift library
│   └── libc++_shared.so    # C++ runtime (required)
└── x86_64/                 # x86_64 (emulator)
    ├── libFoodshareCore.so
    └── libc++_shared.so
```

## Building

From the repository root:

```bash
cd FoodshareCore
./scripts/build-android.sh all debug
```

This will:
1. Cross-compile FoodshareCore for ARM64 and x86_64
2. Copy the resulting `.so` files to this directory

## Requirements

- Swift SDK for Android (nightly)
- Android NDK r27d
- Swift nightly toolchain (matching SDK version)

See `FoodshareCore/scripts/setup-android-sdk.sh` for setup instructions.
