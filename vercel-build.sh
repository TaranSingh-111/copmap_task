#!/bin/bash

set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git \
  --depth 1 -b stable /tmp/flutter

export PATH="/tmp/flutter/bin:$PATH"

# Enable web
flutter config --enable-web

# Generate .env BEFORE building
cat > .env <<EOF
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
EOF

# Generate Google Maps configuration
cat > web/maps-config.js <<EOF
window.COPMAP_MAPS_API_KEY = "$GOOGLE_MAPS_API_KEY";
EOF

# Install dependencies
flutter pub get

# Build production version
flutter build web --release