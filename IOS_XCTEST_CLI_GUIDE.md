# Running iOS XCTest on HydraLab via CLI (curl)

This guide explains how to run iOS XCTest tests on HydraLab using curl commands for CI/CD automation.

## Prerequisites

### 1. HydraLab Setup
- HydraLab Center running (default: `http://localhost:9886`)
- HydraLab Agent running and connected to Center
- iOS device connected and detected by the agent

### 2. Test Package Requirements
- **Build Type**: Use **Release** or **Profile** builds (NOT Debug)
  - Flutter debug builds fail on iOS 14+ without Flutter tooling attached
- **Package Format**: ZIP file containing:
  - `.app` bundle (main application)
  - `.xctestrun` file OR `.xctestproducts` directory
  - Test bundle (`.xctest`) inside the app's `PlugIns/` folder

**Example structure:**
```
hydralab_test_package.zip
└── Release-Prod-iphoneos/
    ├── Runner.app/
    │   ├── PlugIns/
    │   │   └── RunnerTests.xctest/
    │   └── Frameworks/
    └── Runner_iphoneos.xctestrun
```

### 3. Environment Variables (Optional)
```bash
export HYDRALAB_URL="http://localhost:9886"
export DEVICE_UDID="your-ios-device-udid"
export TEAM_NAME="Default"
```

---

## Step-by-Step Guide

### Step 1: Verify HydraLab Center is Running

```bash
curl -s "${HYDRALAB_URL:-http://localhost:9886}/api/center/isAlive"
```

**Expected Response:**
```json
{"code":200,"content":{"status":"OK"},"message":"OK!"}
```

### Step 2: List Available Devices

```bash
curl -s "${HYDRALAB_URL:-http://localhost:9886}/api/device/list" | python3 -m json.tool
```

**Look for iOS devices with:**
- `"type": "IOS"`
- `"status": "ONLINE"`
- Note the `deviceId` (UDID) for later use

### Step 3: Upload Test Package

```bash
curl -s -X POST "${HYDRALAB_URL:-http://localhost:9886}/api/package/add" \
  -F "appFile=@/path/to/your/hydralab_test_package.zip" \
  -F "teamName=${TEAM_NAME:-Default}" \
  -F "commitId=$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')" \
  -F "commitMessage=iOS XCTest execution" \
  -F "buildType=release"
```

**Expected Response:**
```json
{
  "code": 200,
  "content": {
    "id": "2b338e4f-033d-4d99-8578-68221e5326af",
    "appName": "YourApp",
    "packageName": "com.example.app",
    "version": "1.0.0"
  },
  "message": "OK!"
}
```

**Save the `id` value as `FILE_SET_ID`:**
```bash
FILE_SET_ID="2b338e4f-033d-4d99-8578-68221e5326af"
```

### Step 4: Trigger iOS XCTest Execution

```bash
curl -s -X POST "${HYDRALAB_URL:-http://localhost:9886}/api/test/task/run" \
  -H "Content-Type: application/json" \
  -d '{
    "fileSetId": "'"${FILE_SET_ID}"'",
    "deviceIdentifier": "'"${DEVICE_UDID}"'",
    "runningType": "XCTEST",
    "pkgName": "com.example.app",
    "testScope": "TEST_APP",
    "testTimeOutSec": 1800,
    "frameworkType": "XCTest",
    "disableRecording": true,
    "needUninstall": false,
    "needClearData": false
  }'
```

**Expected Response:**
```json
{
  "code": 200,
  "content": {
    "testTaskId": "95b28443-d9f3-497d-85ab-8e2de6144f07",
    "devices": "c7ad90190806994c5c4d62117b4761adc37674c9"
  },
  "message": "OK!"
}
```

**Save the `testTaskId`:**
```bash
TEST_TASK_ID="95b28443-d9f3-497d-85ab-8e2de6144f07"
```

### Step 5: Monitor Test Status

```bash
curl -s "${HYDRALAB_URL:-http://localhost:9886}/api/test/task/${TEST_TASK_ID}" | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
c = d.get('content', {})
print(f'Status: {c.get(\"status\")}')
print(f'Total Tests: {c.get(\"totalTestCount\")}')
print(f'Failed Tests: {c.get(\"totalFailCount\")}')
print(f'Success Rate: {c.get(\"overallSuccessRate\")}')"
```

**Status Values:**
- `running` - Test is in progress
- `finished` - Test completed
- `error` - Test failed with error
- `canceled` - Test was cancelled

---

## Complete CI Script

```bash
#!/bin/bash
set -e

# Configuration
HYDRALAB_URL="${HYDRALAB_URL:-http://localhost:9886}"
TEST_PACKAGE="${1:-./hydralab_test_package.zip}"
DEVICE_UDID="${DEVICE_UDID}"
TEAM_NAME="${TEAM_NAME:-Default}"
PKG_NAME="${PKG_NAME:-com.example.app}"
TIMEOUT_SEC="${TIMEOUT_SEC:-1800}"
POLL_INTERVAL=30
MAX_WAIT=2000

echo "=== HydraLab iOS XCTest Execution ==="

# Step 1: Check center
echo "[1/5] Checking HydraLab center..."
if ! curl -sf "${HYDRALAB_URL}/api/center/isAlive" > /dev/null; then
  echo "ERROR: HydraLab center not available at ${HYDRALAB_URL}"
  exit 1
fi
echo "✓ Center is alive"

# Step 2: Get device UDID if not provided
if [ -z "$DEVICE_UDID" ]; then
  echo "[2/5] Finding iOS device..."
  DEVICE_UDID=$(curl -s "${HYDRALAB_URL}/api/device/list" | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
for agent in data.get('content', []):
  for device in agent.get('devices', []):
    if device.get('type') == 'IOS' and device.get('status') == 'ONLINE':
      print(device.get('deviceId'))
      exit(0)
" 2>/dev/null)
  
  if [ -z "$DEVICE_UDID" ]; then
    echo "ERROR: No online iOS device found"
    exit 1
  fi
fi
echo "✓ Using device: ${DEVICE_UDID}"

# Step 3: Upload package
echo "[3/5] Uploading test package..."
upload_response=$(curl -s -X POST "${HYDRALAB_URL}/api/package/add" \
  -F "appFile=@${TEST_PACKAGE}" \
  -F "teamName=${TEAM_NAME}" \
  -F "commitId=${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo 'manual')}" \
  -F "commitMessage=${COMMIT_MESSAGE:-iOS XCTest CI}" \
  -F "buildType=release")

FILE_SET_ID=$(echo "$upload_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('id',''))" 2>/dev/null)

if [ -z "$FILE_SET_ID" ] || [ "$FILE_SET_ID" = "null" ]; then
  echo "ERROR: Failed to upload package"
  echo "$upload_response"
  exit 1
fi
echo "✓ Package uploaded: ${FILE_SET_ID}"

# Step 4: Trigger test
echo "[4/5] Triggering XCTest..."
test_response=$(curl -s -X POST "${HYDRALAB_URL}/api/test/task/run" \
  -H "Content-Type: application/json" \
  -d '{
    "fileSetId": "'"${FILE_SET_ID}"'",
    "deviceIdentifier": "'"${DEVICE_UDID}"'",
    "runningType": "XCTEST",
    "pkgName": "'"${PKG_NAME}"'",
    "testScope": "TEST_APP",
    "testTimeOutSec": '"${TIMEOUT_SEC}"',
    "frameworkType": "XCTest",
    "disableRecording": true,
    "needUninstall": false,
    "needClearData": false
  }')

TEST_TASK_ID=$(echo "$test_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('testTaskId',''))" 2>/dev/null)

if [ -z "$TEST_TASK_ID" ] || [ "$TEST_TASK_ID" = "null" ]; then
  echo "ERROR: Failed to trigger test"
  echo "$test_response"
  exit 1
fi
echo "✓ Test started: ${TEST_TASK_ID}"

# Step 5: Poll for completion
echo "[5/5] Waiting for test completion..."
elapsed=0

while [ $elapsed -lt $MAX_WAIT ]; do
  response=$(curl -s "${HYDRALAB_URL}/api/test/task/${TEST_TASK_ID}")
  test_status=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('status','unknown'))" 2>/dev/null)
  
  case "$test_status" in
    finished)
      echo "✓ Test finished"
      break
      ;;
    error)
      echo "✗ Test failed with error"
      error_msg=$(echo "$response" | python3 -c "import sys,json; c=json.load(sys.stdin).get('content',{}); print(c.get('errorMsg') or c.get('testErrorMsg') or 'Unknown error')" 2>/dev/null)
      echo "Error: $error_msg"
      exit 1
      ;;
    canceled)
      echo "✗ Test was canceled"
      exit 1
      ;;
    *)
      echo "  Status: ${test_status} (${elapsed}s elapsed)"
      ;;
  esac
  
  sleep $POLL_INTERVAL
  elapsed=$((elapsed + POLL_INTERVAL))
done

if [ $elapsed -ge $MAX_WAIT ]; then
  echo "✗ Test timed out after ${MAX_WAIT}s"
  exit 1
fi

# Get final results
total_tests=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('totalTestCount',0))" 2>/dev/null)
failed_tests=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('totalFailCount',0))" 2>/dev/null)
success_rate=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content',{}).get('overallSuccessRate','0%'))" 2>/dev/null)

echo ""
echo "=== Test Results ==="
echo "Total Tests: ${total_tests}"
echo "Failed Tests: ${failed_tests}"
echo "Success Rate: ${success_rate}"
echo "Report URL: ${HYDRALAB_URL}/portal/index.html?redirectUrl=/info/task/${TEST_TASK_ID}"

if [ "$failed_tests" -gt 0 ]; then
  echo ""
  echo "✗ Some tests failed"
  exit 1
fi

echo ""
echo "✓ All tests passed"
```

**Usage:**
```bash
chmod +x run_ios_xctest.sh
./run_ios_xctest.sh /path/to/hydralab_test_package.zip
```

---

## Test Configuration Options

### Running Type
| Value | Description |
|-------|-------------|
| `XCTEST` | iOS XCTest (native Apple testing framework) |

### Test Scope
| Value | Description |
|-------|-------------|
| `TEST_APP` | Run all tests in the test bundle |
| `CLASS` | Run specific test class (requires `testSuiteClass`) |

### Optional Parameters

```json
{
  "testPlan": "SmokeTests",           // Specific test plan name
  "testSuiteClass": "LoginTests",     // Specific test class
  "disableRecording": false,          // Enable video recording
  "disableGifEncoder": false,         // Enable GIF generation
  "testRunArgs": {                    // Custom xcodebuild arguments
    "-only-testing": "RunnerTests/LoginTests"
  }
}
```

---

## Troubleshooting

### 1. Flutter Debug Build Error
```
Cannot create a FlutterEngine instance in debug mode without Flutter tooling or Xcode.
```
**Solution**: Build with Release or Profile mode:
```bash
flutter build ios --release
```

### 2. Device Not Found
```bash
# List connected iOS devices
pymobiledevice3 usbmux list
# or
idevice_id -l
```

### 3. xctestrun File Not Found
Ensure your ZIP contains either:
- `.xctestrun` file, OR
- `.xctestproducts` directory

### 4. Test Timeout
Increase `testTimeOutSec` in the request:
```json
{"testTimeOutSec": 3600}
```

### 5. Check Agent Logs
```bash
tail -100 agent_output.log | grep -E "(Error|Exception|XCTest)"
```

---

## API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/center/isAlive` | GET | Check center availability |
| `/api/device/list` | GET | List all devices |
| `/api/package/add` | POST | Upload test package |
| `/api/test/task/run` | POST | Trigger test execution |
| `/api/test/task/{taskId}` | GET | Get test status/results |
| `/api/test/task/cancel/{taskId}` | GET | Cancel running test |

---

## Example: GitHub Actions Integration

```yaml
name: iOS XCTest on HydraLab

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Download test package
        run: |
          # Download your pre-built iOS test package
          curl -L -o hydralab_test_package.zip ${{ vars.TEST_PACKAGE_URL }}
      
      - name: Run iOS XCTest
        env:
          HYDRALAB_URL: ${{ vars.HYDRALAB_URL }}
          DEVICE_UDID: ${{ vars.IOS_DEVICE_UDID }}
          PKG_NAME: com.example.app
        run: |
          chmod +x ./scripts/run_ios_xctest.sh
          ./scripts/run_ios_xctest.sh hydralab_test_package.zip
```

---

## Related Documentation
- [HYDRALAB_CI_API_GUIDE.md](./HYDRALAB_CI_API_GUIDE.md) - General CI/API guide
- [iOS_TEST_EXECUTION_GUIDE.md](./iOS_TEST_EXECUTION_GUIDE.md) - Detailed iOS test architecture
