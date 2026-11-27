#!/bin/bash

set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git \
  --depth 1 -b stable /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"

# Enable web
flutter config --enable-web

# Install dependencies
flutter pub get

# Build production version
flutter build web --release