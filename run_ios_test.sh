#!/bin/bash
# iOS XCTest Runner Script for HydraLab
#
# Usage: ./run_ios_test.sh [OPTIONS]
#
# Options:
#   --disable-recording=true|false   Enable/disable screen recording (default: true)
#   --test-timeout=SECONDS           Test timeout in seconds (default: 1800)
#   --test-scope=SCOPE               Test scope: TEST_APP|PACKAGE|CLASS (default: TEST_APP)
#   --test-suite-class=CLASS         Specific test class to run (optional)
#   --skip-install=true|false        Skip app installation (default: false)
#   --need-uninstall=true|false      Uninstall app after test (default: true)
#   --need-clear-data=true|false     Clear app data before test (default: true)
#   --retry-time=N                   Number of retries (default: 0)
#   --device-id=UDID                 Specific device UDID (optional, auto-detect if not set)
#   --help                           Show this help
#
# Available XCTest API Options:
#   fileSetId          - Package file set ID (auto-uploaded)
#   deviceIdentifier   - Device UDID
#   runningType        - XCTEST
#   pkgName            - Bundle identifier (e.g., com.example.app)
#   testPkgName        - Test bundle identifier (optional)
#   testScope          - TEST_APP | PACKAGE | CLASS
#   testSuiteClass     - Specific test class/method (for CLASS scope)
#   testTimeOutSec     - Timeout in seconds
#   frameworkType      - XCTest
#   disableRecording   - true/false - disable screen recording
#   disableGifEncoder  - true/false - disable GIF encoding
#   skipInstall        - true/false - skip app installation
#   needUninstall      - true/false - uninstall after test
#   needClearData      - true/false - clear data before test
#   retryTime          - Number of retries on failure
#   testRunArgs        - Additional test arguments (JSON object)
#   enableTestOrchestrator - true/false

# Default values
HYDRALAB_URL="http://localhost:9886"
TEST_PACKAGE="/Users/abhishek.bedi/peet/HydraLab/hydralab_test_package.zip"
PKG_NAME="com.6alabat.cuisineApp"
AGENT_LOG="/Users/abhishek.bedi/peet/HydraLab/agent_output.log"

# Configurable options with defaults
DISABLE_RECORDING="true"
TEST_TIMEOUT="1800"
TEST_SCOPE="TEST_APP"
TEST_SUITE_CLASS=""
SKIP_INSTALL="false"
NEED_UNINSTALL="true"
NEED_CLEAR_DATA="true"
RETRY_TIME="0"
DEVICE_ID=""

# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --disable-recording=*)
      DISABLE_RECORDING="${arg#*=}"
      ;;
    --test-timeout=*)
      TEST_TIMEOUT="${arg#*=}"
      ;;
    --test-scope=*)
      TEST_SCOPE="${arg#*=}"
      ;;
    --test-suite-class=*)
      TEST_SUITE_CLASS="${arg#*=}"
      ;;
    --skip-install=*)
      SKIP_INSTALL="${arg#*=}"
      ;;
    --need-uninstall=*)
      NEED_UNINSTALL="${arg#*=}"
      ;;
    --need-clear-data=*)
      NEED_CLEAR_DATA="${arg#*=}"
      ;;
    --retry-time=*)
      RETRY_TIME="${arg#*=}"
      ;;
    --device-id=*)
      DEVICE_ID="${arg#*=}"
      ;;
    --help)
      head -40 "$0" | tail -38
      exit 0
      ;;
  esac
done

echo "=== HydraLab iOS XCTest Runner ==="
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│                    INPUT PARAMETERS                        │"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│ %-25s : %-30s │\n" "HydraLab URL" "$HYDRALAB_URL"
printf "│ %-25s : %-30s │\n" "Test Package" "$(basename "$TEST_PACKAGE")"
printf "│ %-25s : %-30s │\n" "Package Name" "$PKG_NAME"
echo "├─────────────────────────────────────────────────────────────┤"
printf "│ %-25s : %-30s │\n" "Disable Recording" "$DISABLE_RECORDING"
printf "│ %-25s : %-30s │\n" "Test Timeout (sec)" "$TEST_TIMEOUT"
printf "│ %-25s : %-30s │\n" "Test Scope" "$TEST_SCOPE"
printf "│ %-25s : %-30s │\n" "Test Suite Class" "${TEST_SUITE_CLASS:-<not set>}"
printf "│ %-25s : %-30s │\n" "Skip Install" "$SKIP_INSTALL"
printf "│ %-25s : %-30s │\n" "Need Uninstall" "$NEED_UNINSTALL"
printf "│ %-25s : %-30s │\n" "Need Clear Data" "$NEED_CLEAR_DATA"
printf "│ %-25s : %-30s │\n" "Retry Time" "$RETRY_TIME"
printf "│ %-25s : %-30s │\n" "Device ID" "${DEVICE_ID:-<auto-detect>}"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# Step 1: Check center
echo "[1/5] Checking HydraLab center..."
if ! curl -sf "${HYDRALAB_URL}/api/center/isAlive" > /dev/null 2>&1; then
  echo "ERROR: HydraLab center not available"
  exit 1
fi
echo "✓ Center is alive"

# Step 2: Find iOS device
echo ""
echo "[2/5] Finding iOS device..."

if [ -n "$DEVICE_ID" ]; then
  # Use provided device ID
  DEVICE_UDID="$DEVICE_ID"
  DEVICE_INFO=$(curl -s "${HYDRALAB_URL}/api/device/list" | python3 -c "
import sys, json
device_id = '$DEVICE_ID'
data = json.load(sys.stdin)
for agent in data.get('content', []):
  for device in agent.get('devices', []):
    if device.get('deviceId') == device_id:
      print(f'{device.get(\"name\")}|{device.get(\"osVersion\")}|{device.get(\"status\")}')
      exit(0)
print('UNKNOWN|UNKNOWN|UNKNOWN')
" 2>/dev/null)
  DEVICE_NAME=$(echo "$DEVICE_INFO" | cut -d'|' -f1)
  DEVICE_OS=$(echo "$DEVICE_INFO" | cut -d'|' -f2)
  echo "✓ Using specified device: $DEVICE_NAME (iOS $DEVICE_OS) - $DEVICE_UDID"
else
  # Auto-detect first online iOS device
  DEVICE_INFO=$(curl -s "${HYDRALAB_URL}/api/device/list" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for agent in data.get('content', []):
  for device in agent.get('devices', []):
    if device.get('type') == 'IOS' and device.get('status') == 'ONLINE':
      print(f'{device.get(\"deviceId\")}|{device.get(\"name\")}|{device.get(\"osVersion\")}')
      exit(0)
print('NOT_FOUND')
" 2>/dev/null)

  if [ "$DEVICE_INFO" = "NOT_FOUND" ] || [ -z "$DEVICE_INFO" ]; then
    echo "ERROR: No online iOS device found"
    exit 1
  fi

  DEVICE_UDID=$(echo "$DEVICE_INFO" | cut -d'|' -f1)
  DEVICE_NAME=$(echo "$DEVICE_INFO" | cut -d'|' -f2)
  DEVICE_OS=$(echo "$DEVICE_INFO" | cut -d'|' -f3)
  echo "✓ Found: $DEVICE_NAME (iOS $DEVICE_OS) - $DEVICE_UDID"
fi

# Step 3: Upload package
echo ""
echo "[3/5] Uploading test package..."
UPLOAD_RESPONSE=$(curl -s -X POST "${HYDRALAB_URL}/api/package/add" \
  -F "appFile=@${TEST_PACKAGE}" \
  -F "teamName=Default" \
  -F "buildType=release")

FILE_SET_ID=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('id',''))" 2>/dev/null)

if [ -z "$FILE_SET_ID" ] || [ "$FILE_SET_ID" = "null" ]; then
  echo "ERROR: Failed to upload package"
  echo "$UPLOAD_RESPONSE"
  exit 1
fi
echo "✓ FileSetID: $FILE_SET_ID"

# Step 4: Trigger test
echo ""
echo "[4/5] Triggering XCTest..."

# Build optional testSuiteClass field
TEST_SUITE_JSON=""
if [ -n "$TEST_SUITE_CLASS" ]; then
  TEST_SUITE_JSON=",\"testSuiteClass\": \"$TEST_SUITE_CLASS\""
fi

# Convert string booleans to JSON booleans
DISABLE_REC_BOOL="$DISABLE_RECORDING"
SKIP_INST_BOOL="$SKIP_INSTALL"
NEED_UNINST_BOOL="$NEED_UNINSTALL"
NEED_CLEAR_BOOL="$NEED_CLEAR_DATA"

TEST_RESPONSE=$(curl -s -X POST "${HYDRALAB_URL}/api/test/task/run" \
  -H "Content-Type: application/json" \
  -d '{
    "fileSetId": "'"$FILE_SET_ID"'",
    "deviceIdentifier": "'"$DEVICE_UDID"'",
    "runningType": "XCTEST",
    "pkgName": "'"$PKG_NAME"'",
    "testScope": "'"$TEST_SCOPE"'",
    "testTimeOutSec": '"$TEST_TIMEOUT"',
    "frameworkType": "XCTest",
    "disableRecording": '"$DISABLE_REC_BOOL"',
    "skipInstall": '"$SKIP_INST_BOOL"',
    "needUninstall": '"$NEED_UNINST_BOOL"',
    "needClearData": '"$NEED_CLEAR_BOOL"',
    "retryTime": '"$RETRY_TIME"''"$TEST_SUITE_JSON"'
  }')

TEST_TASK_ID=$(echo "$TEST_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('testTaskId',''))" 2>/dev/null)

if [ -z "$TEST_TASK_ID" ] || [ "$TEST_TASK_ID" = "null" ]; then
  echo "ERROR: Failed to trigger test"
  echo "$TEST_RESPONSE"
  exit 1
fi
echo "✓ TaskID: $TEST_TASK_ID"

# Step 5: Monitor test and logs
echo ""
echo "[5/5] Monitoring test execution..."
echo "Portal: ${HYDRALAB_URL}/portal/index.html?redirectUrl=/info/task/${TEST_TASK_ID}"
echo ""

POLL_INTERVAL=15
MAX_WAIT=300
elapsed=0

while [ $elapsed -lt $MAX_WAIT ]; do
  response=$(curl -s "${HYDRALAB_URL}/api/test/task/${TEST_TASK_ID}")
  test_status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('status','unknown'))" 2>/dev/null)
  total=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('totalTestCount',0))" 2>/dev/null)
  failed=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('totalFailCount',0))" 2>/dev/null)
  
  echo "[${elapsed}s] Status: $test_status | Tests: $total | Failed: $failed"
  
  if [ "$test_status" = "finished" ] || [ "$test_status" = "error" ] || [ "$test_status" = "canceled" ]; then
    break
  fi
  
  sleep $POLL_INTERVAL
  elapsed=$((elapsed + POLL_INTERVAL))
done

echo ""
echo "=== Final Status ==="
echo "Status: $test_status"
echo "Total Tests: $total"
echo "Failed Tests: $failed"

echo ""
echo "=== Recent Agent Logs (XCTest related) ==="
tail -100 "$AGENT_LOG" 2>/dev/null | grep -E "(XCTest|xcodebuild|unzip|Error|Exception|test-without-building|\.xctestrun)" -i | tail -20

echo ""
echo "=== Test Result Folder ==="
RESULT_DIR=$(find /Users/abhishek.bedi/peet/HydraLab/storage/test/result -type d -name "$DEVICE_UDID" 2>/dev/null | sort | tail -1)
if [ -n "$RESULT_DIR" ]; then
  echo "Path: $RESULT_DIR"
  ls -la "$RESULT_DIR" 2>/dev/null | tail -10
  
  # Check for errors in app log
  APP_LOG=$(find "$RESULT_DIR" -name "*.log" -type f 2>/dev/null | head -1)
  if [ -n "$APP_LOG" ]; then
    echo ""
    echo "=== Errors from App Log ==="
    grep -E "(Error|error|fail|TEST EXECUTE FAILED)" -i "$APP_LOG" 2>/dev/null | tail -10
  fi
fi
