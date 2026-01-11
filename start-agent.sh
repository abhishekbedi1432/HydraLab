#!/bin/bash

##############################################################################
# HydraLab Agent Start Script
#
# This script starts the HydraLab Agent service with proper environment
# configuration for device detection (tidevice, adb, appium, etc.)
#
# Usage:
#   ./start-agent.sh               # Start in foreground (see logs)
#   ./start-agent.sh &             # Start in background
#   nohup ./start-agent.sh &       # Start in background with no hangup
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
echo -e "${BLUE}  HydraLab Agent Startup Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "$HYDRALAB_HOME/agent/build/libs/agent.jar" ]; then
    echo -e "${RED}ERROR: Agent JAR not found at $HYDRALAB_HOME/agent/build/libs/agent.jar${NC}"
    echo -e "${YELLOW}Please run: ./gradlew clean :agent:bootJar${NC}"
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

# Set up PATH with essential tools for device detection
export PATH="/Users/abhishek.bedi/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

echo ""
echo -e "${BLUE}Checking Environment...${NC}"
echo ""

# Check for adb (Android Debug Bridge)
if command -v adb &> /dev/null; then
    ADB_VERSION=$(adb version 2>&1 | grep "Android Debug Bridge" | head -1)
    echo -e "${GREEN}✓${NC} adb: Available"
else
    echo -e "${YELLOW}⚠${NC}  adb not found in PATH"
    echo -e "${YELLOW}   Android device support may not work${NC}"
fi

# Check for tidevice (iOS device detection)
if command -v tidevice &> /dev/null; then
    TIDEVICE_VERSION=$(tidevice --version 2>&1 | head -1)
    echo -e "${GREEN}✓${NC} tidevice: $TIDEVICE_VERSION"
else
    echo -e "${YELLOW}⚠${NC}  tidevice not found in PATH"
    echo -e "${YELLOW}   iOS device support may not work${NC}"
fi

# Check for appium (iOS test execution)
if command -v appium &> /dev/null; then
    APPIUM_VERSION=$(appium --version 2>&1 | head -1)
    echo -e "${GREEN}✓${NC} appium: $APPIUM_VERSION"
else
    echo -e "${YELLOW}⚠${NC}  appium not found in PATH"
    echo -e "${YELLOW}   iOS test execution may not work${NC}"
fi

# Check for Java
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | grep -oP '(?<=version ").*(?=")')
    echo -e "${GREEN}✓${NC} Java: $JAVA_VERSION"
else
    echo -e "${RED}ERROR: Java not found${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Starting HydraLab Agent...${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${YELLOW}Logs will appear below. Press Ctrl+C to stop.${NC}"
echo ""

# Change to HydraLab directory
cd "$HYDRALAB_HOME"

# Start Agent
java -jar agent/build/libs/agent.jar --spring.config.additional-location=application.yml

# If we reach here, the Agent has stopped
echo ""
echo -e "${YELLOW}HydraLab Agent has stopped${NC}"
