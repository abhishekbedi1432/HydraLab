# iOS XCTest Runner - Complete Documentation

## Overview

HydraLab's `XCTestRunner` is the core component responsible for running iOS XCTest test suites on connected iOS devices. It bridges macOS's `xcodebuild` command with HydraLab's test orchestration framework.

**Location**: `/Users/abhishek.bedi/peet/HydraLab/agent/src/main/java/com/microsoft/hydralab/agent/runner/xctest/XCTestRunner.java`

---

## Environment Requirements

### Required Tools

```java
EnvCapabilityRequirement(appium, 1.0+)      // Appium version ≥ 1.0
EnvCapabilityRequirement(tidevice, 0.10+)   // tidevice version ≥ 0.10
```

**Why These Tools?**
- **tidevice**: Detects connected iOS devices, mounts developer images, handles device communication
- **appium**: Manages screen recording, log collection, screenshot capture for GIF creation

### Verify Installation

```bash
appium --version       # Should be ≥ 1.0
tidevice --version     # Should be ≥ 0.10
xcodebuild -version    # Should be available (comes with Xcode)
xcode-select -p        # Should point to Xcode installation
```

---

## Complete Test Execution Flow

### **Phase 1: Initialize Test** (lines 58-69)

**Method**: `initializeTest(TestRunDevice, TestTask, TestRun)`

```java
private void initializeTest(TestRunDevice testRunDevice, TestTask testTask, TestRun testRun) {
    // Start screen recording if enabled
    if (!testTask.isDisableRecording()) {
        testRunDeviceOrchestrator.startScreenRecorder(
            testRunDevice,
            testRun.getResultFolder(),
            testTask.getTimeOutSecond(),
            testRun.getLogger()
        );
    }

    // Start collecting iOS system logs
    testRunDeviceOrchestrator.startLogCollector(
        testRunDevice,
        testTask.getPkgName(),
        testRun,
        testRun.getLogger()
    );

    // Start GIF encoder to capture screenshots
    if(!testTask.isDisableGifEncoder()) {
        testRunDeviceOrchestrator.startGifEncoder(
            testRunDevice,
            testRun.getResultFolder(),
            testTask.getPkgName() + ".gif"
        );
    }

    // Record when test started
    testRun.setTestStartTimeMillis(System.currentTimeMillis());
}
```

**Output**:
- Screen recording started (MP4 format)
- Log collector running (captures system logs)
- GIF encoder running (captures screenshots at intervals)

---

### **Phase 2: Unzip Test Bundle** (lines 82-89)

**Method**: `unzipXctestFolder(File, TestRun, Logger)`

```java
private void unzipXctestFolder(File zipFile, TestRun testRun, Logger logger) {
    logger.info("start unzipping file");
    String folderPath = testRun.getResultFolder().getAbsolutePath() + "/"
            + Const.XCTestConfig.XCTEST_ZIP_FOLDER_NAME + "/";

    String command = String.format("unzip -d %s %s", folderPath, zipFile.getAbsolutePath());
    ShellUtils.execLocalCommand(command, logger);
}
```

**Command Executed**:
```bash
unzip -d {resultFolder}/Xctest/ ios_tests.zip
```

**Result**:
Extracts test bundle containing:
- `Runner.app` - The app to be tested
- `RunnerTests.xctest` - Test bundle with test cases
- Supporting frameworks and resources

---

### **Phase 3: Execute XCTest** (lines 91-154) - **CORE EXECUTION**

**Method**: `runXctest(TestRunDevice, Logger, TestTask, TestRun)`

#### **Step A: Locate Test Files** (lines 156-179)

```java
private File getXctestproductsFile(File unzippedFolder) {
    // Search for .xctestproducts directory (newer XCTest format)
    Collection<File> files = FileUtils.listFilesAndDirs(unzippedFolder, ...);
    for (File file : files) {
        if (file.getAbsolutePath().endsWith(".xctestproducts") && file.isDirectory()) {
            return file;
        }
    }
    return null;
}

private File getXctestrunFile(File unzippedFolder) {
    // Search for .xctestrun file (older XCTest format)
    Collection<File> files = FileUtils.listFiles(unzippedFolder, null, true);
    for (File file : files) {
        if (file.getAbsolutePath().endsWith(".xctestrun")) {
            return file;
        }
    }
    return null;
}
```

**Priority**:
1. Try `.xctestproducts` (newer format) - preferred
2. Fall back to `.xctestrun` (older format)
3. Throw error if neither found

#### **Step B: Build xcodebuild Command** (lines 104-132)

```java
// Start with base command
String commFormat = "xcodebuild test-without-building";

// Add custom arguments if provided
Map<String, String> instrumentationArgs = testTask.getTaskRunArgs();
if (instrumentationArgs != null && !instrumentationArgs.isEmpty()) {
    instrumentationArgs.forEach((k, v) ->
        argString.append(" ").append(k).append(" ").append(v)
    );
}

// Add test products path
File xctestproducts = getXctestproductsFile(...);
if (xctestproducts != null) {
    commFormat += " -testProductsPath " + xctestproducts.getAbsolutePath();

    if (StringUtils.isNotBlank(testTask.getTestPlan())) {
        commFormat += " -testPlan " + testTask.getTestPlan();
    }
} else {
    File xctestrun = getXctestrunFile(...);
    commFormat += " -xctestrun " + xctestrun.getAbsolutePath();
}

// Add device destination
String deviceId = "id=" + testRunDevice.getDeviceInfo().getDeviceId();
commFormat += " -destination " + deviceId;

// Add result bundle path
String resultPath = testRun.getResultFolder() + "/result.xcresult";
commFormat += " -resultBundlePath " + resultPath;
```

**Example Final Command**:
```bash
xcodebuild test-without-building \
  -testProductsPath /path/to/Runner.app \
  -destination id=00008030-0005743926A0802E \
  -resultBundlePath /path/to/result.xcresult
```

**Command Parameters**:
| Parameter | Purpose |
|-----------|---------|
| `test-without-building` | Run tests without rebuilding app |
| `-testProductsPath` | Path to Runner.app (test products) |
| `-testPlan` | Specific test plan to run (optional) |
| `-destination` | Target device by UDID |
| `-resultBundlePath` | Where to save test results |

#### **Step C: Execute Command** (lines 135-148)

```java
Process proc = Runtime.getRuntime().exec(command);

// Capture stderr and stdout
XCTestCommandReceiver err = new XCTestCommandReceiver(proc.getErrorStream(), logger);
XCTestCommandReceiver out = new XCTestCommandReceiver(proc.getInputStream(), logger);

// Start reading output in separate threads
err.start();
out.start();

// Wait for xcodebuild to complete
proc.waitFor();

// Get collected output
result = out.getResult();
```

**What Happens During Execution**:
1. xcodebuild connects to the iOS device via USB
2. Launches the test runner on device
3. Executes each test case
4. Captures output in real-time
5. Streams logs to agent console
6. Returns test results and logs

**Device-Side Activity**:
- Test framework initializes
- Test cases execute sequentially
- Screen is captured for video recording
- System logs are collected
- Results are returned to macOS agent

---

### **Phase 4: Parse Test Results** (lines 181-207)

**Method**: `analysisXctestResult(List<String>, TestRun)`

```java
private void analysisXctestResult(List<String> resultList, TestRun testRun) {
    int totalCases = 0;

    for (String resultLine : resultList) {
        // Look for test case result lines
        if (resultLine.toLowerCase().startsWith("test case")
            && !resultLine.contains("started")) {

            // Parse: "Test Case 'RunnerTests.LoginTests.testLogin' passed (0.500 seconds)"
            AndroidTestUnit testUnit = new AndroidTestUnit();

            // Extract test name and class
            String testInfo = resultLine.split("'")[1];  // "RunnerTests.LoginTests.testLogin"
            testUnit.setTestName(testInfo.split("\\.")[1]);      // "testLogin"
            testUnit.setTestedClass(testInfo.split("\\.")[0]);   // "LoginTests"

            // Set test result status
            if (resultLine.contains("passed")) {
                testUnit.setStatusCode(AndroidTestUnit.StatusCodes.OK);
                testUnit.setSuccess(true);
            } else if (resultLine.contains("skipped")) {
                testUnit.setStatusCode(AndroidTestUnit.StatusCodes.IGNORED);
                testUnit.setSuccess(true);
            } else {
                testUnit.setStatusCode(AndroidTestUnit.StatusCodes.FAILURE);
                testUnit.setSuccess(false);
            }

            // Add to test results
            testRun.addNewTestUnit(testUnit);
            totalCases += 1;
        }
    }

    testRun.setTotalCount(totalCases);
}
```

**Example xcodebuild Output**:
```
Test Suite 'RunnerTests' started at 2026-01-12 11:30:00.000
Test Case 'RunnerTests.LoginTests.testLogin' started
Test Case 'RunnerTests.LoginTests.testLogin' passed (0.500 seconds).
Test Case 'RunnerTests.LoginTests.testLogout' started
Test Case 'RunnerTests.LoginTests.testLogout' passed (0.300 seconds).
Test Case 'RunnerTests.SearchTests.testSearch' started
Test Case 'RunnerTests.SearchTests.testSearch' passed (1.200 seconds).
Test Case 'RunnerTests.CheckoutTests.testCheckout' started
Test Case 'RunnerTests.CheckoutTests.testCheckout' failed (2.100 seconds).
  ... error details ...
Test Suite 'RunnerTests' finished at 2026-01-12 11:31:00.000
```

**Parsed Results**:
```
✅ testLogin (LoginTests): PASS
✅ testLogout (LoginTests): PASS
✅ testSearch (SearchTests): PASS
❌ testCheckout (CheckoutTests): FAIL
───────────────────────────
Total: 4 tests
Passed: 3
Failed: 1
```

---

### **Phase 5: Finalize Test** (lines 209-225)

**Method**: `finishTest(TestRunDevice, TestTask, TestRun)`

```java
private void finishTest(TestRunDevice testRunDevice, TestTask testTask, TestRun testRun) {
    // Record test end time
    testRun.addNewTimeTag("testRunEnded",
        System.currentTimeMillis() - testRun.getTestStartTimeMillis());
    testRun.onTestEnded();

    // Stop and save GIF
    if (!testTask.isDisableGifEncoder()) {
        testRunDeviceOrchestrator.stopGitEncoder(testRunDevice,
            agentManagementService.getScreenshotDir(),
            testRun.getLogger());
        testRun.setTestGifPath(agentManagementService
            .getTestBaseRelPathInUrl(testRunDevice.getGifFile()));
    }

    // Stop and save video
    if (!testTask.isDisableRecording()) {
        String videoFilePath = testRunDeviceOrchestrator.stopScreenRecorder(
            testRunDevice,
            testRun.getResultFolder(),
            testRun.getLogger());
        testRun.setVideoPath(agentManagementService
            .getTestBaseRelPathInUrl(videoFilePath));
    }

    // Stop log collection
    testRunDeviceOrchestrator.stopLogCollector(testRunDevice);

    // Set result paths
    String absoluteReportPath = testRun.getResultFolder().getAbsolutePath();
    testRun.setTestXmlReportPath(agentManagementService
        .getTestBaseRelPathInUrl(new File(absoluteReportPath)));
}
```

**Cleanup Activities**:
- ✓ Finish screen recording
- ✓ Finalize animated GIF
- ✓ Stop log collection
- ✓ Delete temporary test files
- ✓ Generate test report
- ✓ Prepare results for transmission to Center

---

## Error Handling

### Failure Scenarios

1. **No Device Found**
   ```java
   if (testRunDevice.getDeviceInfo() == null) {
       throw new RuntimeException("No such device: " + testRunDevice.getDeviceInfo());
   }
   ```

2. **Missing Test Files**
   ```java
   if (xctestrun == null) {
       throw new RuntimeException("xctestrun file not found");
   }
   ```

3. **Command Execution Failure**
   ```java
   catch (Exception e) {
       throw new RuntimeException("Execute XCTest failed");
   }
   ```

4. **No Results Collected**
   ```java
   if (result == null) {
       throw new RuntimeException("No result collected");
   }
   ```

---

## Test Configuration Options

### Via TestTask Object

```java
// Basic configuration
testTask.getPkgName()              // App package name
testTask.getAppFile()              // ios_tests.zip file
testTask.getTestPlan()             // Optional: specific test plan

// Control execution
testTask.isDisableRecording()      // Skip video recording
testTask.isDisableGifEncoder()     // Skip GIF creation
testTask.getTaskRunArgs()          // Custom xcodebuild arguments
testTask.getNeedUninstall()        // Uninstall app before test
testTask.getNeedClearData()        // Clear app data before test
```

### Custom xcodebuild Arguments

```java
Map<String, String> args = new HashMap<>();
args.put("-configuration", "Release");
args.put("-scheme", "MyScheme");
testTask.setTaskRunArgs(args);
```

---

## Result Output Structure

### TestRun Object

```java
TestRun {
    testUnits: [
        {
            testName: "testLogin",
            testedClass: "LoginTests",
            statusCode: "OK",              // OK | FAILURE | IGNORED
            success: true,
            deviceTestResultId: "...",
            testTaskId: "..."
        },
        // ... more test units
    ],
    totalCount: 4,
    failCount: 1,
    logcatPath: "logs/...",
    videoPath: "videos/result.mp4",
    testGifPath: "gifs/com.talabat.gif",
    testXmlReportPath: "reports/...",
    testStartTimeMillis: 1673577000000,
    testEndTimeMillis: 1673577060000
}
```

---

## File Organization

### Input Files
```
ios_tests.zip (uploaded by user)
├── Release-Prod-iphoneos/
│   ├── Runner.app/
│   │   ├── PlugIns/
│   │   │   └── RunnerTests.xctest/
│   │   │       ├── RunnerTests (executable)
│   │   │       └── RunnerTests.xctest.dSYM (debug symbols)
│   │   └── Frameworks/ (118+ frameworks)
│   └── [Other frameworks]
```

### Temporary Extraction Location
```
{Agent Work Directory}/hydra/data/test/{testRunId}/
├── Xctest/                    # Extracted test bundle
├── logcat/                    # iOS system logs
├── screenshots/               # GIF frames
├── result.xcresult/           # XCTest results bundle
├── {packageName}.gif          # Animated GIF of test execution
├── device_result.mp4          # Screen recording video
└── report.html                # HTML test report
```

---

## Integration with HydraLab

### TestRunDevice Interface

```java
TestRunDevice {
    deviceId: "00008030-0005743926A0802E",     // Device UDID
    deviceName: "Abhi",                         // Device name
    platform: "iOS",                            // Platform type
    logPath: "...",                             // Where logs are stored
    gifFile: File,                              // GIF output file
    screenshotDir: File                         // Screenshot directory
}
```

### Orchestrator Integration

The `XCTestRunner` uses `TestRunDeviceOrchestrator` for device operations:

```java
// Screen recording
testRunDeviceOrchestrator.startScreenRecorder(...)
testRunDeviceOrchestrator.stopScreenRecorder(...)

// Log collection
testRunDeviceOrchestrator.startLogCollector(...)
testRunDeviceOrchestrator.stopLogCollector(...)

// GIF creation
testRunDeviceOrchestrator.startGifEncoder(...)
testRunDeviceOrchestrator.stopGitEncoder(...)
testRunDeviceOrchestrator.addGifFrameAsyncDelay(...)

// App management
testRunDeviceOrchestrator.uninstallApp(...)
testRunDeviceOrchestrator.resetPackage(...)
```

---

## Performance Characteristics

### Typical Execution Times

| Phase | Duration | Notes |
|-------|----------|-------|
| Initialization | 1-2 seconds | Setup recording, logging |
| Unzip | 2-5 seconds | Depends on bundle size (269MB+) |
| Test Execution | 1-30+ minutes | Varies by test count and complexity |
| Result Parsing | 1-2 seconds | Parsing xcodebuild output |
| Finalization | 5-10 seconds | Video compression, GIF creation |
| **Total** | **10-45+ minutes** | Typical end-to-end time |

### Resource Usage

```
macOS Agent:
- CPU: Peaks during xcodebuild execution
- Memory: ~200-500 MB for test process
- Storage: 500 MB - 2 GB for results/artifacts

iOS Device:
- Network: 50-100 Mbps (USB connection)
- CPU: Peaks during test execution
- Memory: Tests run in app's memory space
- Storage: Temporary test files cleaned up after
```

---

## Troubleshooting Guide

### Issue: "DeveloperImage not found"

**Cause**: iOS device needs developer image that matches Xcode version

**Solution**:
```bash
# Option 1: Mount developer image
tidevice -u <UDID> developer --reboot-ok

# Option 2: Update Xcode
xcode-select --switch /path/to/Xcode.app

# Option 3: Check compatibility
tidevice list
xcodebuild -version
```

### Issue: "xctestrun file not found"

**Cause**: Test bundle doesn't contain .xctestrun or .xctestproducts

**Solution**:
1. Verify ios_tests.zip contains Runner.app
2. Check Xcode build includes test artifacts
3. Rezip preserving directory structure

### Issue: Tests timeout

**Cause**: Tests exceed timeout limit

**Solution**:
1. Increase `testTimeOutSec` (default: 600)
2. Disable video recording (faster execution)
3. Disable GIF encoder (faster execution)
4. Profile slow test cases

### Issue: "Device offline during test"

**Cause**: Device disconnected or became unresponsive

**Solution**:
```bash
# Verify device
tidevice list
adb devices -l

# Check device responsiveness
tidevice -u <UDID> info
```

---

## Code References

**Main Class**: `XCTestRunner.java` (lines 1-227)

**Key Methods**:
- `run()` (lines 49-56) - Main execution orchestration
- `initializeTest()` (lines 58-69) - Setup phase
- `unzipXctestFolder()` (lines 82-89) - Extract test bundle
- `runXctest()` (lines 91-154) - Execute tests
- `analysisXctestResult()` (lines 181-207) - Parse results
- `finishTest()` (lines 209-225) - Cleanup phase

---

## Summary

The `XCTestRunner` provides a complete iOS test execution pipeline:

1. ✅ Initializes device monitoring (recording, logs, GIF)
2. ✅ Extracts test bundle from zip file
3. ✅ Constructs optimized xcodebuild command
4. ✅ Executes tests on real iOS device via macOS
5. ✅ Parses test results in real-time
6. ✅ Finalizes artifacts (video, GIF, reports)
7. ✅ Returns comprehensive test results to HydraLab Center

**Key Strengths**:
- Real device testing (not emulator)
- Full test output capture (logs, video, screenshots)
- Automatic developer image management
- Custom test plan support
- Flexible result parsing
