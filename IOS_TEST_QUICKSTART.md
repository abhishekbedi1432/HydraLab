# iOS Test Quick Start Guide

## Run iOS Tests on HydraLab via CLI

### Prerequisites ✓

- [x] HydraLab Center running at `http://localhost:9886`
- [x] iOS device connected: **iPhone 11 Pro** (UDID: `00008030-0005743926A0802E`)
- [x] Test package: `/Users/abhishek.bedi/Downloads/ios_tests.zip`
- [x] Python 3 installed
- [x] `tidevice` installed

### Step 1: Install Required Python Packages

```bash
pip3 install requests
```

### Step 2: Generate HydraLab Auth Token

**Option A: Auto-Generate via API (Quickest)**

```bash
# Generate and export token in one command
export HYDRALAB_AUTH_TOKEN=$(curl -s "http://localhost:9886/api/auth/create" | jq -r '.content.token')
echo "Token: $HYDRALAB_AUTH_TOKEN"
```

**Option B: Via Web Portal**

1. Open http://localhost:9886/portal/index.html#/auth
2. Login with your credentials
3. Click "Create Token"
4. Copy the generated token
5. Export it:
   ```bash
   export HYDRALAB_AUTH_TOKEN='your-token-here'
   ```

**Option C: Manual Export (if you already have a token)**

```bash
export HYDRALAB_AUTH_TOKEN='your-token-here'
```

### Step 3: Run iOS Tests

```bash
cd /Users/abhishek.bedi/peet/HydraLab
python3 run_ios_tests.py
```

**Or in one command:**

```bash
export HYDRALAB_AUTH_TOKEN=$(curl -s "http://localhost:9886/api/auth/create" | jq -r '.content.token') && \
cd /Users/abhishek.bedi/peet/HydraLab && \
python3 run_ios_tests.py
```

### Expected Output

```
HydraLab iOS Test Runner
======================================================================

======================================================================
Detecting iOS Devices
======================================================================
✓ Found iOS device:
  - Name: Abhi
  - Model: iPhone 11 Pro
  - UDID: 00008030-0005743926A0802E

======================================================================
Checking HydraLab Center
======================================================================
✓ HydraLab Center is running (version: 0.0.0)

======================================================================
Verifying Test Package
======================================================================
✓ Test file found: /Users/abhishek.bedi/Downloads/ios_tests.zip (311.8 MB)
✓ Found iOS app: Runner.app
✓ Found XCTest bundle: RunnerTests

======================================================================
Uploading Test Package
======================================================================
✓ Package uploaded successfully
  - File Set ID: f00634b6-16af-4f7c-b34f-e7e3f6c1163c
  - Package Name: com.6alabat.cuisineApp

======================================================================
Triggering Test Execution
======================================================================
Test configuration:
{
  "fileSetId": "f00634b6-16af-4f7c-b34f-e7e3f6c1163c",
  "deviceIdentifier": "00008030-0005743926A0802E",
  "runningType": "XCTEST",
  "pkgName": "RunnerTests",
  "testPkgName": "RunnerTests",
  "testTimeOutSec": 900,
  "frameworkType": "XCTest",
  "skipInstall": false,
  "needUninstall": true,
  "needClearData": true,
  "disableRecording": false,
  "disableGifEncoder": false,
  "pipelineLink": "CLI Test Run",
  "deviceTestCount": 1
}

✓ Test task started
  - Task ID: 90d11276-e487-433a-bc8b-82c15e7a41e4
  - Device: 00008030-0005743926A0802E

======================================================================
Monitoring Test Execution
======================================================================
Watch progress: http://localhost:9886/portal/index.html#/device
Test report: http://localhost:9886/portal/index.html?redirectUrl=/info/task/90d11276-e487-433a-bc8b-82c15e7a41e4

[11:46:12] Test status: running
✓ Test finished

======================================================================
Test Results
======================================================================
Device: Abhi (1 device(s))
Total tests: XX (or 0 if tests need configuration)
Passed: XX
Failed: 0
Success rate: 100.0%

Full report: http://localhost:9886/portal/index.html?redirectUrl=/info/task/90d11276-e487-433a-bc8b-82c15e7a41e4

✓ All tests passed!
```

**Note:** If you see "Total tests: 0", this means:
- The test bundle was uploaded and executed successfully
- But no tests were found/executed (possible reasons below)
- Check the full report link for detailed logs

---

## Customization Options

### Custom Test File Location

```bash
cd /Users/abhishek.bedi/peet/HydraLab
python3 -c "
from run_ios_tests import HydraLabIOSTestRunner
runner = HydraLabIOSTestRunner(
    test_file='/path/to/your/ios_tests.zip'
)
runner.run()
"
```

### Custom HydraLab URL

```bash
cd /Users/abhishek.bedi/peet/HydraLab
python3 -c "
from run_ios_tests import HydraLabIOSTestRunner
runner = HydraLabIOSTestRunner(
    hydralab_url='http://your-hydralab-server:9886',
    test_file='/path/to/ios_tests.zip'
)
runner.run()
"
```

### Custom Team Name

```bash
cd /Users/abhishek.bedi/peet/HydraLab
python3 -c "
from run_ios_tests import HydraLabIOSTestRunner
runner = HydraLabIOSTestRunner(
    team_name='YourTeamName'
)
runner.run()
"
```

---

## Integration with CI/CD

### GitHub Actions

```yaml
- name: Run iOS Tests on HydraLab
  env:
    HYDRALAB_AUTH_TOKEN: ${{ secrets.HYDRALAB_TOKEN }}
  run: |
    python3 run_ios_tests.py
```

### GitLab CI

```yaml
test_ios:
  script:
    - export HYDRALAB_AUTH_TOKEN="${HYDRALAB_TOKEN}"
    - python3 run_ios_tests.py
```

### Jenkins

```groovy
withCredentials([string(credentialsId: 'hydralab-token', variable: 'HYDRALAB_AUTH_TOKEN')]) {
    sh 'python3 run_ios_tests.py'
}
```

---

## Common Issues & Solutions

### Issue: "Total tests: 0" after successful execution

This means the test ran but no tests were detected. Possible causes:

1. **Test bundle doesn't contain runnable tests**
   - Check if .xctest bundle has actual test methods
   - Verify test methods are prefixed with `test`
   - Example: `func testLogin() { ... }`

2. **Wrong test target selected**
   - Your package might need specific test plan or scheme
   - Check the full report for xcodebuild output

3. **Test configuration needs adjustment**
   - May need to specify `testSuiteClass` or `testScope`
   - Check if app requires specific launch arguments

**Solution:** Check the detailed logs in the web portal:
```
http://localhost:9886/portal/index.html?redirectUrl=/info/task/YOUR_TASK_ID
```

---

## Troubleshooting

### Error: "tidevice command not found"

```bash
pip3 install tidevice
```

### Error: "No iOS device found"

```bash
# Check if device is connected
tidevice list

# Make sure device is trusted
# On iOS device: Settings → General → VPN & Device Management
```

### Error: "HYDRALAB_AUTH_TOKEN not set"

Generate a token from HydraLab portal and export it:

```bash
export HYDRALAB_AUTH_TOKEN='your-token-here'
```

### Error: "Cannot connect to HydraLab center"

Check if HydraLab center is running:

```bash
curl http://localhost:9886/api/center/info
```

If not running, start it:

```bash
cd /Users/abhishek.bedi/peet/HydraLab
java -jar center/build/libs/center.jar
```

---

## What the Script Does

1. **Detects iOS Device** - Automatically finds connected iPhone/iPad via `tidevice`
2. **Validates Test Package** - Checks for `.app` and `.xctest` bundles
3. **Uploads to HydraLab** - Sends test package to center
4. **Triggers Test Run** - Starts XCTest execution on device
5. **Monitors Progress** - Polls for test completion
6. **Displays Results** - Shows pass/fail summary with links to full report

---

## Script Features

- ✅ Auto-detects connected iOS devices
- ✅ Validates test package structure
- ✅ Color-coded terminal output
- ✅ Real-time status monitoring
- ✅ Detailed error messages
- ✅ Links to full test reports
- ✅ Exit codes for CI/CD (0 = success, 1 = failure)
- ✅ Platform-agnostic (works on Mac/Linux)

---

## Files Created

- `run_ios_tests.py` - Main test runner script
- `IOS_TEST_QUICKSTART.md` - This guide

**Location:** `/Users/abhishek.bedi/peet/HydraLab/`

---

## Next Steps

1. Generate your auth token
2. Run `python3 run_ios_tests.py`
3. View full test report in HydraLab portal
4. Integrate into your CI/CD pipeline

Happy Testing! 🚀
