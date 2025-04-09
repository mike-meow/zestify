#!/bin/bash

# Setup Ruby environment
source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
chruby ruby-3.4.2

# Add Ruby bin to PATH
export PATH="$HOME/.rubies/ruby-3.4.2/bin:$PATH"

# Verify CocoaPods is available
echo "CocoaPods version: $(pod --version)"

# Run Flutter
flutter "$@"
