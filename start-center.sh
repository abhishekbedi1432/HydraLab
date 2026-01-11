#!/bin/bash

##############################################################################
# HydraLab Center Start Script
#
# This script starts the HydraLab Center service with proper environment
# configuration for iOS device detection (tidevice, appium, etc.)
#
# Usage:
#   ./start-center.sh              # Start in foreground (see logs)
#   ./start-center.sh &            # Start in background
#   nohup ./start-center.sh &      # Start in background with no hangup
#
##############################################################################

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYDRALAB_HOME="$SCRIPT_DIR"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  HydraLab Center Startup Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "$HYDRALAB_HOME/center/build/libs/center.jar" ]; then
    echo -e "${RED}ERROR: Center JAR not found at $HYDRALAB_HOME/center/build/libs/center.jar${NC}"
    echo -e "${YELLOW}Please run: ./gradlew clean :center:bootJar${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} HydraLab Home: $HYDRALAB_HOME"

# Check for required configuration file
if [ ! -f "$HYDRALAB_HOME/application.yml" ]; then
    echo -e "${YELLOW}⚠${NC}  Warning: application.yml not found"
    echo -e "${YELLOW}   Using default configuration${NC}"
else
    echo -e "${GREEN}✓${NC} Configuration: $HYDRALAB_HOME/application.yml"
fi

# Set up PATH with essential tools
export PATH="/Users/abhishek.bedi/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

echo ""
echo -e "${BLUE}Checking Environment...${NC}"
echo ""

# Check for tidevice
if command -v tidevice &> /dev/null; then
    TIDEVICE_VERSION=$(tidevice --version 2>&1 | head -1)
    echo -e "${GREEN}✓${NC} tidevice: $TIDEVICE_VERSION"
else
    echo -e "${YELLOW}⚠${NC}  tidevice not found in PATH"
    echo -e "${YELLOW}   iOS device support may not work${NC}"
fi

# Check for appium
if command -v appium &> /dev/null; then
    APPIUM_VERSION=$(appium --version 2>&1 | head -1)
    echo -e "${GREEN}✓${NC} appium: $APPIUM_VERSION"
else
    echo -e "${YELLOW}⚠${NC}  appium not found in PATH"
    echo -e "${YELLOW}   iOS test execution may not work${NC}"
fi

# Check for Java
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | grep 'version' | sed -E 's/.*version \"([^"]+)\".*/\1/')
    echo -e "${GREEN}✓${NC} Java: $JAVA_VERSION"
else
    echo -e "${RED}ERROR: Java not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Starting HydraLab Center...${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}Logs will appear below. Press Ctrl+C to stop.${NC}"
echo ""

# Change to HydraLab directory
cd "$HYDRALAB_HOME"

# Start Center
java -jar center/build/libs/center.jar --spring.config.additional-location=application.yml

# If we reach here, the Center has stopped
echo ""
echo -e "${YELLOW}HydraLab Center has stopped${NC}"
