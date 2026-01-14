# Talabat Android Test Configuration Guide

## Configuration Summary

### APK Files to Use
- **App APK**: `/Users/abhishek.bedi/peet/talabat-mobile-app-flutter/gCloudDownloadsForFTL/app-universal-profile.apk`
- **Test APK**: `/Users/abhishek.bedi/peet/talabat-mobile-app-flutter/gCloudDownloadsForFTL/app-debug-androidTest.apk`

### Extracted Package Information
- **Main App Package**: `com.talabat`
- **Test Package**: `com.talabat.test`
- **Test Runner**: `androidx.test.runner.AndroidJUnitRunner`
- **Framework**: JUnit4
- **App Size**: 269 MB (main), 2.0 MB (test)

---

## Step-by-Step Configuration

### Step 1: Upload Files via HydraLab API

**Endpoint**: `POST http://localhost:9886/api/package/add`

**Command**:
```bash
curl -X POST "http://localhost:9886/api/package/add" \
  -F "appFile=@/Users/abhishek.bedi/peet/talabat-mobile-app-flutter/gCloudDownloadsForFTL/app-universal-profile.apk" \
  -F "testAppFile=@/Users/abhishek.bedi/peet/talabat-mobile-app-flutter/gCloudDownloadsForFTL/app-debug-androidTest.apk" \
  -F "teamName=default" \
  -F "commitId=main" \
  -F "commitMessage=Talabat Android Tests"
```

**Response** (example):
```json
{
  "id": "file-set-talabat-001",
  "appName": "Talabat",
  "packageName": "com.talabat",
  "version": "1.0.0",
  "teamId": "team-001",
  "attachments": [
    {
      "fileType": "APP_FILE",
      "fileName": "app-universal-profile.apk",
      "fileId": "file-talabat-app",
      "md5": "...",
      "fileLen": 281313280
    },
    {
      "fileType": "TEST_APP_FILE",
      "fileName": "app-debug-androidTest.apk",
      "fileId": "file-talabat-test",
      "md5": "...",
      "fileLen": 2097152
    }
  ]
}
```

**Save the `id` value** - you'll use it as `fileSetId` in the next step.

---

### Step 2: Create Test Task via HydraLab API

**Endpoint**: `POST http://localhost:9886/api/test/task/run`

**Full Request (JSON)**:
```json
{
  "fileSetId": "file-set-talabat-001",
  "deviceIdentifier": "ce0617166b244c630d7e",
  "runningType": "INSTRUMENTATION",
  "pkgName": "com.talabat",
  "testPkgName": "com.talabat.test",
  "testAppPath": "app-debug-androidTest.apk",
  "testScope": "TEST_APP",
  "testRunnerName": "androidx.test.runner.AndroidJUnitRunner",
  "testTimeOutSec": 600,
  "frameworkType": "JUnit4",
  "skipInstall": false,
  "needUninstall": true,
  "needClearData": true,
  "deviceTestCount": 1,
  "enableTestOrchestrator": false,
  "disableRecording": false,
  "disableGifEncoder": false
}
```

**Using curl**:
```bash
curl -X POST "http://localhost:9886/api/test/task/run" \
  -H "Content-Type: application/json" \
  -d '{
    "fileSetId": "file-set-talabat-001",
    "deviceIdentifier": "ce0617166b244c630d7e",
    "runningType": "INSTRUMENTATION",
    "pkgName": "com.talabat",
    "testPkgName": "com.talabat.test",
    "testAppPath": "app-debug-androidTest.apk",
    "testScope": "TEST_APP",
    "testRunnerName": "androidx.test.runner.AndroidJUnitRunner",
    "testTimeOutSec": 600,
    "frameworkType": "JUnit4",
    "skipInstall": false,
    "needUninstall": true,
    "needClearData": true,
    "disableRecording": false,
    "disableGifEncoder": false
  }'
```

**Response**:
```json
{
  "testTaskId": "task-talabat-123",
  "devices": "ce0617166b244c630d7e",
  "status": "STARTED"
}
```

---

## Configuration Field Explanations

### Required Fields

| Field | Value | Explanation |
|-------|-------|-------------|
| **fileSetId** | file-set-talabat-001 | From Step 1 upload response |
| **deviceIdentifier** | ce0617166b244c630d7e | Your Android device serial number |
| **runningType** | INSTRUMENTATION | Android Espresso/JUnit tests |
| **pkgName** | com.talabat | Main app package from APK |
| **testPkgName** | com.talabat.test | Test package from test APK |

### Android-Specific Fields

| Field | Value | Explanation |
|-------|-------|-------------|
| **testAppPath** | app-debug-androidTest.apk | Test APK file name from attachments |
| **testScope** | TEST_APP | Run all tests in the test application |
| **testRunnerName** | androidx.test.runner.AndroidJUnitRunner | Instrumentation test runner |
| **testTimeOutSec** | 600 | 10 minutes timeout for all tests |
| **frameworkType** | JUnit4 | JUnit 4 framework (standard for Espresso) |

### Installation Options

| Field | Value | Explanation |
|-------|-------|-------------|
| **skipInstall** | false | Install both APKs (don't skip) |
| **needUninstall** | true | Uninstall app before test |
| **needClearData** | true | Clear app data (fresh test environment) |

### Optional Fields

| Field | Value | Explanation |
|-------|-------|-------------|
| **deviceTestCount** | 1 | Run test once per device (1-5 typical) |
| **enableTestOrchestrator** | false | Don't use Test Orchestrator (optional) |
| **disableRecording** | false | Enable video recording (recommended) |
| **disableGifEncoder** | false | Enable GIF creation (recommended) |

---

## Alternative Configurations

### Option 1: Run Specific Test Class (Instead of All Tests)

Replace `testScope` and add `testSuiteClass`:

```json
{
  ...existing fields...,
  "testScope": "CLASS",
  "testSuiteClass": "com.talabat.test.LoginTests",
  ...
}
```

### Option 2: Run Tests with Custom Arguments

Add `testRunArgs`:

```json
{
  ...existing fields...,
  "testRunArgs": {
    "clearPackageData": "false",
    "disableAnalytics": "true"
  }
}
```

### Option 3: Grant Permissions Before Test

Add `neededPermissions`:

```json
{
  ...existing fields...,
  "neededPermissions": [
    "android.permission.CAMERA",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.READ_CONTACTS"
  ]
}
```

### Option 4: Run on Multiple Devices

For device groups, use:

```json
{
  ...existing fields...,
  "deviceIdentifier": "G.AllAndroidDevices",
  "groupTestType": "SAME_TEST_SET"
}
```

---

## HydraLab Portal Method (GUI)

If you prefer the web interface instead of API:

### Steps:
1. **Open HydraLab Portal**: http://localhost:9886/portal

2. **Navigate to**: Test → New Test Task

3. **Fill Configuration**:
   - **Test Type**: AndroidJUnitRunner / INSTRUMENTATION
   - **App Package**: com.talabat
   - **Test Package**: com.talabat.test
   - **Device**: Your Android device
   - **App APK**: app-universal-profile.apk (upload)
   - **Test APK**: app-debug-androidTest.apk (upload)
   - **Timeout**: 600 seconds
   - **Uninstall Before Test**: ✓ Enabled
   - **Clear Data Before Test**: ✓ Enabled
   - **Recording**: ✓ Enabled
   - **GIF Encoder**: ✓ Enabled

4. **Click Submit**

5. **Monitor**: View real-time test execution in Devices View

---

## Expected Test Execution Flow

### Phase 1: Installation (1-2 minutes)
```
✓ Installing com.talabat (main app) ... 269 MB
✓ Main app installed successfully
✓ Installing com.talabat.test (test APK) ... 2 MB
✓ Test APK installed successfully
```

### Phase 2: Test Execution (Time varies with test count)
```
✓ Initializing AndroidJUnitRunner
✓ Starting com.talabat with test runner
✓ Test Case 1: com.talabat.test.LoginTests.testLogin ... PASS
✓ Test Case 2: com.talabat.test.LoginTests.testLogout ... PASS
✓ Test Case 3: com.talabat.test.SearchTests.testSearch ... PASS
✓ Test Case 4: com.talabat.test.CheckoutTests.testCheckout ... FAIL (example)
... (more test cases)
```

### Phase 3: Results Collection (30-60 seconds)
```
✓ Stopping test runner
✓ Collecting logs and screenshots
✓ Compressing video recording
✓ Creating animated GIF
✓ Cleaning up temporary files
✓ Test execution completed
```

---

## Monitoring Test Execution

### Check Agent Logs:
```bash
# Watch agent logs for test progress
tail -f /Users/abhishek.bedi/peet/HydraLab/agent.log | grep -E "(Installing|Test Case|PASS|FAIL|onAllComplete)"
```

### Expected Log Entries:
1. **Installation phase**:
   ```
   Installing app file: com.talabat
   adb install -r app-universal-profile.apk
   Installation complete: com.talabat
   Installing test file: com.talabat.test
   adb install app-debug-androidTest.apk
   Installation complete: com.talabat.test
   ```

2. **Execution phase**:
   ```
   Starting instrumentation: com.talabat.test/androidx.test.runner.AndroidJUnitRunner
   adb shell am instrument -w com.talabat.test/androidx.test.runner.AndroidJUnitRunner
   Test Case 'com.talabat.test.LoginTests.testLogin' passed
   Test Case 'com.talabat.test.LoginTests.testLogout' passed
   ```

3. **Results phase**:
   ```
   Total test count: 25
   Passed: 24
   Failed: 1
   Skipped: 0
   onAllComplete at [timestamp]
   ```

---

## Troubleshooting

### Issue 1: "Test package not installed"
**Cause**: Test APK upload failed
**Solution**: Verify test APK size (should be ~2 MB), check upload response

### Issue 2: "Main app package not installed"
**Cause**: Main APK upload failed or wrong package name
**Solution**: Verify app APK size (should be ~269 MB), verify package is `com.talabat`

### Issue 3: "No tests found"
**Cause**: Test APK doesn't contain test classes
**Solution**: Verify app-debug-androidTest.apk contains test classes (check in APK PlugIns folder)

### Issue 4: "Test timeout (600s exceeded)"
**Cause**: Tests taking longer than timeout
**Solution**: Increase `testTimeOutSec` to 900 (15 minutes) or disable video recording

### Issue 5: "Device offline during test"
**Cause**: Device disconnected or became unresponsive
**Solution**: Check device connection with `adb devices`, verify device is not in use

---

## Device Identifier Verification

**Your Android Device**:
- Serial: ce0617166b244c630d7e
- Verify with: `adb devices`

---

## Next Action

Ready to run Talabat tests! Choose one method:

### Method A: Quick API Call
```bash
# Make sure you have the fileSetId from Step 1
curl -X POST "http://localhost:9886/api/test/task/run" \
  -H "Content-Type: application/json" \
  -d '{
    "fileSetId": "YOUR_FILE_SET_ID",
    "deviceIdentifier": "ce0617166b244c630d7e",
    "runningType": "INSTRUMENTATION",
    "pkgName": "com.talabat",
    "testPkgName": "com.talabat.test",
    "testAppPath": "app-debug-androidTest.apk",
    "testScope": "TEST_APP",
    "testRunnerName": "androidx.test.runner.AndroidJUnitRunner",
    "testTimeOutSec": 600,
    "frameworkType": "JUnit4"
  }'
```

### Method B: Use Web Portal
1. Go to http://localhost:9886/portal
2. Test → New Test Task
3. Fill in the values from this configuration
4. Click Submit

### Method C: Use Gradle Plugin (in CI/CD)
```gradle
hydralab {
    appFile = file("app-universal-profile.apk")
    testFile = file("app-debug-androidTest.apk")
    pkgName = "com.talabat"
    testPkgName = "com.talabat.test"
    deviceId = "ce0617166b244c630d7e"
    testTimeOutSec = 600
}
```

---

## Summary

| Component | Value |
|-----------|-------|
| App APK | app-universal-profile.apk (269 MB) |
| Test APK | app-debug-androidTest.apk (2 MB) |
| Main Package | com.talabat |
| Test Package | com.talabat.test |
| Test Runner | androidx.test.runner.AndroidJUnitRunner |
| Device | ce0617166b244c630d7e |
| Framework | JUnit4 |
| Timeout | 600 seconds |
| Status | ✅ Ready to Execute |
