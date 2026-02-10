# ⚠️ DEPRECATED - Moved to foodshare-tools

This tools directory has been merged into the unified **foodshare-tools** repository.

## New Location

https://github.com/Foodshareclub/foodshare-tools

## Migration

The unified repository provides the same `foodshare-hooks` binary (now `foodshare-android`) with additional features.

### Option 1: Use the unified repo (recommended)

```bash
# Clone the unified tools repo
git clone https://github.com/Foodshareclub/foodshare-tools.git ../foodshare-tools

# Build
cd ../foodshare-tools
cargo build --release

# Symlink the binary
ln -sf ../../foodshare-tools/target/release/foodshare-android ./target/release/foodshare-hooks
```

### Option 2: Keep using this directory

The existing code still works. Just run:

```bash
cargo build --release
```

## New Features in Unified Repo

- `swift-core` subcommand for building FoodshareCore Swift library for Android
- Shared core with iOS and Web for consistent behavior
- Better test coverage and documentation
