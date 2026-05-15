#!/bin/sh
# install.sh — Install patched LGI for Lua 5.5 system-wide
#
# This installs a patched version of LGI (Lua GObject Introspection) that
# works with Lua 5.5 and modern GLib (2.87+). It replaces any existing
# system LGI installation.
#
# What it installs:
#   - Lua files → /usr/share/lua/5.5/lgi/   (the LGI runtime)
#   - C module  → /usr/lib/lua/5.5/lgi/      (corelgilua51.so)
#
# The bundle is based on lua-lgi-git (0.9.2.r128) with these patches:
#   1. Lua 5.5 const-variable fix (for-loop vars are read-only in 5.5)
#   2. GLib 2.87+ enum iteration fix (ffi.lua)
#
# Requires sudo. Run from the project directory.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$SCRIPT_DIR/lgi-bundle"

if [ ! -d "$BUNDLE" ]; then
    echo "Error: bundle directory not found at $BUNDLE"
    echo "Make sure lgi-bundle/ exists alongside this script."
    exit 1
fi

echo "Installing patched LGI for Lua 5.5..."
echo "  Source: $BUNDLE"
echo "  Target: /usr/share/lua/5.5/ and /usr/lib/lua/5.5/"
echo ""

# Copy Lua files
sudo cp -v "$BUNDLE/lgi.lua" /usr/share/lua/5.5/
sudo cp -rv "$BUNDLE/lgi" /usr/share/lua/5.5/

# Copy C module (compiled for Lua 5.5)
sudo mkdir -p /usr/lib/lua/5.5/lgi/
sudo cp -v "$BUNDLE/corelgilua51.so" /usr/lib/lua/5.5/lgi/

echo ""
echo "Done. Verify with: lua -e 'require(\"lgi\"); print(\"LGI OK\")'"