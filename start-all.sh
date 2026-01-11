#!/bin/bash

##############################################################################
# HydraLab Complete Startup Script
#
# This script starts both HydraLab Center and Agent services
#
# Usage:
#   ./start-all.sh                 # Start both services in separate terminals
#   ./start-all.sh --foreground    # Start both in foreground (debug mode)
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
echo -e "${BLUE}  HydraLab Complete Startup Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check for required JAR files
if [ ! -f "$HYDRALAB_HOME/center/build/libs/center.jar" ]; then
    echo -e "${RED}ERROR: Center JAR not found${NC}"
    echo -e "${YELLOW}Please run: ./gradlew clean :center:bootJar${NC}"
    exit 1
fi

if [ ! -f "$HYDRALAB_HOME/agent/build/libs/agent.jar" ]; then
    echo -e "${RED}ERROR: Agent JAR not found${NC}"
    echo -e "${YELLOW}Please run: ./gradlew clean :agent:bootJar${NC}"
    exit 1
fi

# Check for scripts
if [ ! -x "$HYDRALAB_HOME/start-center.sh" ]; then
    echo -e "${RED}ERROR: start-center.sh not found or not executable${NC}"
    exit 1
fi

if [ ! -x "$HYDRALAB_HOME/start-agent.sh" ]; then
    echo -e "${RED}ERROR: start-agent.sh not found or not executable${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} All required files found"
echo ""

# Check for mode
FOREGROUND=false
if [ "$1" == "--foreground" ]; then
    FOREGROUND=true
    echo -e "${YELLOW}Mode: FOREGROUND (debug)${NC}"
else
    echo -e "${YELLOW}Mode: BACKGROUND (production)${NC}"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Starting HydraLab Services...${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ "$FOREGROUND" = true ]; then
    # Foreground mode - start both with visible logs
    echo -e "${YELLOW}Starting Center and Agent in foreground...${NC}"
    echo -e "${YELLOW}Each service will run in this terminal${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""

    # Start Center first
    echo -e "${BLUE}>>> Starting Center...${NC}"
    "$HYDRALAB_HOME/start-center.sh"
else
    # Background mode - start both in separate terminals/background

    # Check if we can open new terminals
    if command -v open &> /dev/null; then
        # macOS - open in new terminal windows
        echo -e "${YELLOW}Starting Center in new terminal window...${NC}"
        open -a Terminal "$HYDRALAB_HOME/start-center.sh" &
        sleep 2

        echo -e "${YELLOW}Starting Agent in new terminal window...${NC}"
        open -a Terminal "$HYDRALAB_HOME/start-agent.sh" &

        echo ""
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}  Services Started!${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""
        echo -e "${GREEN}Center${NC}:  http://localhost:9886/portal"
        echo ""
        echo -e "${YELLOW}Waiting 5 seconds for services to initialize...${NC}"
        sleep 5

        echo ""
        echo -e "${GREEN}✓${NC} Services are starting"
        echo -e "${YELLOW}Check the separate terminal windows for logs${NC}"
        echo ""
        echo -e "${BLUE}To check if services are running:${NC}"
        echo -e "  ${YELLOW}ps aux | grep java${NC}"
        echo ""
        echo -e "${BLUE}To stop the services:${NC}"
        echo -e "  ${YELLOW}pkill -f center/build/libs/center.jar${NC}"
        echo -e "  ${YELLOW}pkill -f agent/build/libs/agent.jar${NC}"
        echo ""
    else
        # Linux/Unix - start in background
        echo -e "${YELLOW}Starting Center in background...${NC}"
        nohup "$HYDRALAB_HOME/start-center.sh" > "$HYDRALAB_HOME/center.log" 2>&1 &
        CENTER_PID=$!
        echo -e "${GREEN}✓${NC} Center started (PID: $CENTER_PID)"

        sleep 3

        echo -e "${YELLOW}Starting Agent in background...${NC}"
        nohup "$HYDRALAB_HOME/start-agent.sh" > "$HYDRALAB_HOME/agent.log" 2>&1 &
        AGENT_PID=$!
        echo -e "${GREEN}✓${NC} Agent started (PID: $AGENT_PID)"

        echo ""
        echo -e "${GREEN}================================================${NC}"
        echo -e "${GREEN}  Services Started!${NC}"
        echo -e "${GREEN}================================================${NC}"
        echo ""
        echo -e "${GREEN}Center${NC}:  http://localhost:9886/portal"
        echo ""
        echo -e "${BLUE}Logs:${NC}"
        echo -e "  Center: ${YELLOW}$HYDRALAB_HOME/center.log${NC}"
        echo -e "  Agent:  ${YELLOW}$HYDRALAB_HOME/agent.log${NC}"
        echo ""
        echo -e "${BLUE}To view logs:${NC}"
        echo -e "  ${YELLOW}tail -f $HYDRALAB_HOME/center.log${NC}"
        echo -e "  ${YELLOW}tail -f $HYDRALAB_HOME/agent.log${NC}"
        echo ""
        echo -e "${BLUE}To stop the services:${NC}"
        echo -e "  ${YELLOW}kill $CENTER_PID $AGENT_PID${NC}"
        echo -e "  Or: ${YELLOW}pkill -f center/build/libs/center.jar${NC}"
        echo -e "  Or: ${YELLOW}pkill -f agent/build/libs/agent.jar${NC}"
        echo ""
    fi
fi
