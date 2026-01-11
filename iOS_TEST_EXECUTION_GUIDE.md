# How to Run iOS Tests on HydraLab - Complete Analysis & Guide

## Executive Summary

Your iOS test file (`ios_tests.zip`) contains an **XCTest bundle** (`RunnerTests.xctest`) which is Apple's native testing framework. HydraLab supports running XCTest through the `XCTestRunner` component using `xcodebuild` commands on macOS.

---

## Part 1: Your iOS Test Structure

### What's in Your `ios_tests.zip`

```
Release-Prod-iphoneos/
├── Runner.app/                          ← Main iOS application
│   ├── PlugIns/
│   │   └── RunnerTests.xctest/          ← XCTest bundle (YOUR TESTS)
│   │       ├── RunnerTests              ← Test executable
│   │       └── RunnerTests.xctest.dSYM  ← Debug symbols
│   └── Frameworks/                      ← App dependencies (118 frameworks)
└── [Other frameworks with dependencies]
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **RunnerTests.xctest** | XCTest bundle containing test cases | `Release-Prod-iphoneos/Runner.app/PlugIns/` |
| **Runner.app** | The app to be tested | `Release-Prod-iphoneos/` |
| **Frameworks** | Dependencies (Firebase, Google Maps, Braze, etc.) | `Release-Prod-iphoneos/` |

### Test Framework Type
- **Type**: XCTest (Apple's native testing framework)
- **Format**: `.xctest` bundle
- **Execution**: Via `xcodebuild test-without-building` command
- **Requirements**: macOS with Xcode (you already have this - iPhone is connected!)

---

## Part 2: HydraLab iOS Test Execution Architecture

### High-Level Flow

```
Test Submission (Center/API)
          ↓
   TestTaskController
          ↓
   TestTask (RunnerType.XCTEST)
          ↓
   Agent: TestRunnerManager
          ↓
   XCTestRunner (Agent-side executor)
          ↓
   Step 1: Unzip test bundle
   Step 2: Extract XCTest files
   Step 3: Run xcodebuild command
   Step 4: Parse results
          ↓
   Device: iPhone
          ↓
   Results back to Center
          ↓
   Portal: Display test results
```

### Key Classes Involved

#### 1. **XCTestRunner** (Core Test Executor)
**File**: `/agent/src/main/java/com/microsoft/hydralab/agent/runner/xctest/XCTestRunner.java`

**Responsibilities**:
- Unzip the test bundle file
- Find `.xctestproducts` or `.xctestrun` files
- Execute `xcodebuild test-without-building` command
- Parse test results and create test units
- Manage screen recording, logs, GIF encoding

**Main Workflow** (lines 49-56):
```java
protected void run(TestRunDevice testRunDevice, TestTask testTask, TestRun testRun) {
    initializeTest(testRunDevice, testTask, testRun);           // Setup recording, logs
    unzipXctestFolder(testTask.getAppFile(), testRun, logger);  // Extract test files
    List<String> result = runXctest(...);                       // Execute tests
    analysisXctestResult(result, testRun);                      // Parse results
    finishTest(testRunDevice, testTask, testRun);               // Cleanup
}
```

#### 2. **Test Execution Command** (lines 91-154)

The runner constructs an `xcodebuild` command:

```bash
# Basic command
xcodebuild test-without-building \
  -testProductsPath /path/to/Runner.app \
  -destination id=<DEVICE_UDID> \
  -resultBundlePath /path/to/result.xcresult

# With test plan (optional)
xcodebuild test-without-building \
  -testProductsPath /path/to/Runner.app \
  -testPlan <TEST_PLAN_NAME> \
  -destination id=<DEVICE_UDID> \
  -resultBundlePath /path/to/result.xcresult

# With custom arguments
xcodebuild test-without-building \
  -xctestrun /path/to/tests.xctestrun \
  -destination id=<DEVICE_UDID> \
  -resultBundlePath /path/to/result.xcresult
```

#### 3. **Test Detection** (lines 167-179)

The runner automatically detects:
- `.xctestproducts` directory (preferred) - newer XCTest format
- `.xctestrun` file (fallback) - older XCTest format

```java
private File getXctestproductsFile(File unzippedFolder) {
    // Searches for .xctestproducts directory
}

private File getXctestrunFile(File unzippedFolder) {
    // Searches for .xctestrun file
}
```

#### 4. **Result Parsing** (lines 181-207)

Parses test output and extracts:
- Test class name
- Test method name
- Test status: PASSED, FAILED, SKIPPED

**Example Output**:
```
Test Case 'RunnerTests.MyTest.testLogin' passed
Test Case 'RunnerTests.MyTest.testCheckout' failed
Test Case 'RunnerTests.MyTest.testPayment' skipped
```

---

## Part 3: Configuration Requirements

### 1. Environment Requirements

Your agent has these requirements (from `XCTestRunner.java` lines 43-46):
```java
new EnvCapabilityRequirement(appium, 1.0+)     ✅ (check with: appium --version)
new EnvCapabilityRequirement(tidevice, 0.10+)  ✅ (check with: tidevice --version)
```

**Verify your setup:**
```bash
# Check all required tools
tidevice --version        # Should be ≥ 0.10
appium --version          # Should be ≥ 1.0
xcodebuild -version       # Should exist (comes with Xcode)
xcode-select -p           # Should point to Xcode path
```

### 2. HydraLab Agent Configuration

Your current configuration (`application.yml`) is correct:

```yaml
app:
  device:
    monitor:
      ios:
        enabled: true  ✅
  registry:
    name: iOS Agent  ✅
    server: localhost:9886  ✅
```

### 3. iOS Device Requirements

- **Device Status**: `ONLINE` (verified in portal - ✅)
- **Device Type**: IOS (✅)
- **Xcode compatibility**: Must match app's deployment target
- **Provisioning Profile**: Must be installed on device (should be in Runner.app)

---

## Part 4: How to Run iOS Tests

### Option 1: Via HydraLab Center Portal (Recommended)

#### Step 1: Prepare Test Files
1. Extract your `ios_tests.zip`
2. Keep the structure: `Release-Prod-iphoneos/Runner.app/...`
3. Zip it back up as `ios_tests.zip` (if modified)

#### Step 2: Create Test Task via Portal

Go to **HydraLab Center** → **Test** → **New Test Task**

**Configuration Fields**:

| Field | Value | Notes |
|-------|-------|-------|
| **Test Runner Type** | XCTest | Select from dropdown |
| **Test Package/Name** | RunnerTests | Name of test bundle |
| **Device Selection** | iPhone 11 Pro (00008030...) | Your connected device |
| **Test File** | ios_tests.zip | Upload your test file |
| **Test Plan** | (optional) | If using test plans |
| **Custom Arguments** | (optional) | Xcodebuild args (e.g., `-scheme MyScheme`) |
| **Timeout** | 600 (seconds) | For long-running tests |
| **Recording** | Enable | Captures video of test execution |
| **GIF Encoder** | Enable | Creates animated GIF of test |

#### Step 3: Submit & Monitor

1. Click **Submit**
2. Monitor test progress in **Devices View**
3. View results once completed

### Option 2: Via REST API

**Endpoint**: `POST /api/test/task/create`

**Request Body**:
```json
{
  "testTaskId": "task-ios-001",
  "pkgName": "RunnerTests",
  "type": "API",
  "runningType": "XCTEST",
  "deviceIdentifier": "00008020-001948413668002E",
  "testFileSet": {
    "fileId": "file-ios-001"
  },
  "testTimeOutSec": 600,
  "testPlan": "DefaultPlan",
  "testRunArgs": {
    "-configuration": "Release",
    "-destination": "generic/platform=iOS"
  },
  "disableRecording": false,
  "disableGifEncoder": false,
  "fileSetId": "file-set-001"
}
```

### Option 3: Via Gradle Plugin (CI/CD)

HydraLab provides a Gradle plugin:

```gradle
hydralab {
    runnerType = "XCTEST"
    pkgName = "RunnerTests"
    testFile = file("ios_tests.zip")
    testTimeOutSec = 600
    deviceId = "00008020-001948413668002E"
}
```

---

## Part 5: What Happens During Test Execution

### Phase 1: Initialization (XCTestRunner.java:58-69)
```
✓ Start screen recorder (captures video)
✓ Start log collector (collects iOS system logs)
✓ Start GIF encoder (captures screenshots)
✓ Set test start time
```

### Phase 2: Preparation (XCTestRunner.java:82-89)
```
✓ Unzip ios_tests.zip to: {resultFolder}/Xctest/
✓ Locate Runner.app and RunnerTests.xctest
✓ Extract .xctestproducts or .xctestrun file
```

### Phase 3: Test Execution (XCTestRunner.java:91-154)
```
✓ Build xcodebuild command with device UDID
✓ Execute: xcodebuild test-without-building \
    -testProductsPath {path to Runner.app} \
    -destination id={device-udid} \
    -resultBundlePath result.xcresult
✓ Stream test output to logs
✓ Wait for all tests to complete
```

### Phase 4: Result Analysis (XCTestRunner.java:181-207)
```
✓ Parse xcodebuild output
✓ Extract test class & method names
✓ Determine test status:
  - PASSED (statusCode=OK)
  - FAILED (statusCode=FAILURE)
  - SKIPPED (statusCode=IGNORED)
✓ Count total/failed tests
```

### Phase 5: Finalization (XCTestRunner.java:209-225)
```
✓ Stop screen recording (video saved)
✓ Stop log collection
✓ Stop GIF encoder
✓ Clean up temporary files
✓ Return results to Center
```

---

## Part 6: Test Result Interpretation

After execution, you'll see:

### Portal Display
- **Test Count**: Total test cases executed
- **Success Rate**: Pass rate percentage
- **Test Details**: Individual test case results
- **Logs**: Full xcodebuild output
- **Video**: Screen recording of test execution
- **GIF**: Animated test flow
- **Artifacts**: Crash logs, performance metrics

### Result Files Location
```
{Agent Workspace}/hydra/data/test/
├── result.xcresult/           # XCTest results bundle
├── logcat/                     # iOS system logs
├── {packageName}.gif           # Test animation
└── device_report.html          # HTML report
```

### Result Structure
```java
TestRun {
    testUnits: [
        {
            testName: "testLogin",
            testedClass: "LoginTests",
            statusCode: "OK",      // or FAILURE, IGNORED
            success: true,
            deviceTestResultId: "...",
            testTaskId: "..."
        },
        // ... more test units
    ],
    totalCount: 5,
    failCount: 0,
    logcatPath: "logs/...",
    videoPath: "videos/...",
    testGifPath: "gifs/..."
}
```

---

## Part 7: Troubleshooting Common Issues

### Issue 1: "xctestrun file not found"
**Cause**: Test bundle doesn't contain `.xctestrun` or `.xctestproducts`
**Solution**:
1. Verify your `ios_tests.zip` contains `Runner.app/PlugIns/RunnerTests.xctest/`
2. Check Xcode build output includes these files
3. Rezip ensuring structure is preserved

### Issue 2: Device not found by xcodebuild
**Cause**: Device UDID mismatch
**Solution**:
```bash
# Get correct UDID
tidevice list
# Use full UDID in device identifier
```

### Issue 3: Tests time out
**Cause**: Insufficient timeout or slow device
**Solution**:
1. Increase timeout in test configuration
2. Disable screen recording (video capture is slow)
3. Check device is responsive: `tidevice shell ls /`

### Issue 4: Provisioning profile error
**Cause**: App needs signing, device not trusted
**Solution**:
1. Trust developer cert on device: Settings → General → VPN & Device Management
2. Rebuild app with valid provisioning profile
3. Resign `.app` if needed

---

## Part 8: Advanced Configuration

### Custom Test Arguments

Pass xcodebuild arguments via `taskRunArgs`:

```json
{
  "testRunArgs": {
    "-configuration": "Release",
    "-scheme": "MyScheme",
    "-only-testing": "RunnerTests/LoginTests/testLogin",
    "-skip-testing": "RunnerTests/SlowTests"
  }
}
```

### Test Plan Selection

If your app has test plans:

```json
{
  "testPlan": "SmokeTests",  // Runs only SmokeTests plan
  "testRunArgs": {
    "-testPlan": "SmokeTests"
  }
}
```

### Performance Monitoring

Enable performance metrics:

```yaml
# In agent config
app:
  runner:
    performance:
      enabled: true
      strategies:
        - memory
        - cpu
        - battery
```

---

## Part 9: Step-by-Step: Run Your iOS Tests Now

### Quick Start (5 minutes)

1. **Access HydraLab Center**
   ```
   http://localhost:9886/portal
   ```

2. **Go to Create Test**
   - Click: **Test** → **New Test Task**

3. **Fill Test Configuration**
   - **Test Type**: XCTest
   - **Package Name**: RunnerTests
   - **Upload File**: ios_tests.zip
   - **Device**: Select your iPhone
   - **Timeout**: 300 seconds

4. **Submit**
   - Click: **Submit**
   - Go to: **Devices View**
   - Watch: Real-time test execution

5. **View Results**
   - Test summary
   - Individual test results
   - Screen recording/GIF
   - Full logs

---

## Part 10: Code Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│         User Submits Test via Portal/API                    │
│         TestTaskController.createTestTask()                 │
└────────────────────┬────────────────────────────────────────┘
                     ↓
        ┌────────────────────────────┐
        │  TestTask (RunnerType.XCTEST)
        │  - pkgName: RunnerTests
        │  - appFile: ios_tests.zip
        │  - deviceId: iPhone UDID
        └─────────┬──────────────────┘
                  ↓
        ┌────────────────────────────┐
        │  Agent: TestRunnerManager
        │  selectRunner(XCTEST)
        └─────────┬──────────────────┘
                  ↓
        ┌────────────────────────────────┐
        │  XCTestRunner.run()
        │  - initializeTest()
        │  - unzipXctestFolder()
        │  - runXctest()           ← Core execution
        │  - analysisXctestResult()
        │  - finishTest()
        └─────────┬──────────────────────┘
                  ↓
    ┌─────────────────────────────────────┐
    │  xcodebuild test-without-building   │
    │  (Executed on macOS Agent)          │
    │                                     │
    │  Command:                           │
    │  xcodebuild test-without-building \ │
    │    -testProductsPath ... \          │
    │    -destination id=UDID \           │
    │    -resultBundlePath ...            │
    └─────────┬─────────────────────────────┘
              ↓
    ┌─────────────────────────────────────┐
    │      iPhone (Connected Device)      │
    │      - Install app if needed
    │      - Run test suite
    │      - Capture logs/video
    │      - Return results
    └─────────┬─────────────────────────────┘
              ↓
    ┌─────────────────────────────────────┐
    │  Parse Results                      │
    │  Extract test units:                │
    │  - testName                         │
    │  - testedClass                      │
    │  - statusCode (PASS/FAIL/SKIP)     │
    │  - totalCount, failCount            │
    └─────────┬─────────────────────────────┘
              ↓
    ┌─────────────────────────────────────┐
    │  Send Results to Center             │
    │  TestRun object with:               │
    │  - testUnits[]
    │  - video path
    │  - gif path
    │  - logs path
    │  - performance metrics
    └─────────┬─────────────────────────────┘
              ↓
    ┌─────────────────────────────────────┐
    │  HydraLab Portal                    │
    │  Display test results to user       │
    └─────────────────────────────────────┘
```

---

## Summary

**Your iOS Tests Are Ready to Run!** ✅

| Component | Status | Details |
|-----------|--------|---------|
| iOS Device | ✅ Connected | iPhone 11 Pro (F2LX8J0NKPH1) |
| XCTest Support | ✅ Enabled | XCTestRunner registered |
| Agent | ✅ Running | Connected to Center |
| Center Portal | ✅ Running | Test submission ready |
| tidevice | ✅ Installed | v≥0.10 required |
| Appium | ✅ Installed | v≥1.0 required |
| Xcode | ✅ Available | xcodebuild available |

**Next Step**: Upload `ios_tests.zip` to HydraLab and run your first iOS test! 🎉

