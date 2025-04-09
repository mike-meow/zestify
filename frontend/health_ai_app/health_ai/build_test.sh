#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Health AI App build and test process...${NC}"

# Step 1: Clean the project
echo -e "\n${YELLOW}Cleaning project...${NC}"
flutter clean

# Step 2: Get dependencies
echo -e "\n${YELLOW}Getting dependencies...${NC}"
flutter pub get

# Step 3: Analyze the code
echo -e "\n${YELLOW}Analyzing code...${NC}"
flutter analyze

# Step 4: Run tests
echo -e "\n${YELLOW}Running tests...${NC}"
flutter test

# Step 5: Build for different platforms
echo -e "\n${YELLOW}Building for iOS (debug mode)...${NC}"
flutter build ios --debug --no-codesign

echo -e "\n${YELLOW}Building for macOS...${NC}"
flutter build macos --debug

echo -e "\n${YELLOW}Building for web...${NC}"
flutter build web

echo -e "\n${GREEN}Build and test completed successfully!${NC}"
