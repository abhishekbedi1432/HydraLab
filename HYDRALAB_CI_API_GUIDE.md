# HydraLab CI/API Integration Guide

## Overview

This guide explains how to use HydraLab programmatically via CLI and APIs for CI/CD automation, eliminating the need for manual uploads through the web portal.

**Target Audience**: DevOps engineers, CI/CD pipeline developers
**Use Case**: Automated testing in continuous integration pipelines

---

## Table of Contents

1. [Authentication Setup](#authentication-setup)
2. [API Endpoints](#api-endpoints)
3. [Integration Methods](#integration-methods)
4. [Complete Workflow](#complete-workflow)
5. [CI/CD Examples](#cicd-examples)
6. [Troubleshooting](#troubleshooting)

---

## Authentication Setup

### Step 1: Generate Authentication Token

HydraLab uses Bearer token authentication for API access.

**Method 1: Via Web Portal**
1. Navigate to `http://<hydralab-center-url>/portal/index.html#/auth`
2. Login with your credentials
3. Click "Create Token" to generate a new API token
4. Save the token securely - you'll need it for all API calls

**Method 2: Via API (after initial login)**
```bash
curl -X GET "http://<hydralab-center-url>/api/auth/create" \
  -H "Authorization: Bearer <your-session-token>"
```

**Response:**
```json
{
  "code": 200,
  "content": {
    "id": 1,
    "token": "your-generated-auth-token-here",
    "creator": "user@example.com"
  }
}
```

### Step 2: Store Token Securely

**For CI/CD environments:**
- Store as environment variable: `HYDRALAB_AUTH_TOKEN`
- Use secret management (Azure Key Vault, GitHub Secrets, etc.)
- Never commit tokens to version control

---

## API Endpoints

### Base URL
```
http://<hydralab-center-url>
```

### Core Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/center/isAlive` | GET | Check center availability |
| `/api/package/add` | POST | Upload app and test packages |
| `/api/package/addAttachment` | POST | Add test attachments/resources |
| `/api/test/task/run` | POST | Trigger test execution |
| `/api/test/task/{testId}` | GET | Get test status/results |
| `/api/test/task/cancel/{testId}` | GET | Cancel running test |
| `/api/device/list` | GET | List available devices |
| `/api/auth/create` | GET | Generate authentication token |

---

## Integration Methods

### Method 1: Direct REST API with curl

#### 1.1 Upload Test Package

```bash
# Upload app and test APK
curl -X POST "http://<hydralab-center-url>/api/package/add" \
  -H "Authorization: Bearer ${HYDRALAB_AUTH_TOKEN}" \
  -F "appFile=@path/to/app-release.apk" \
  -F "testAppFile=@path/to/app-test.apk" \
  -F "teamName=YourTeamName" \
  -F "commitId=${GIT_COMMIT_SHA}" \
  -F "commitCount=${BUILD_NUMBER}" \
  -F "commitMessage=${COMMIT_MESSAGE}" \
  -F "buildType=release"
```

**Response:**
```json
{
  "code": 200,
  "content": {
    "id": "file-set-uuid-12345",
    "appName": "MyApp",
    "packageName": "com.example.app",
    "testAppPackageName": "com.example.app.test"
  }
}
```

Save the `id` value as `FILE_SET_ID` for the next step.

#### 1.2 Trigger Test Run

```bash
curl -X POST "http://<hydralab-center-url>/api/test/task/run" \
  -H "Authorization: Bearer ${HYDRALAB_AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "fileSetId": "'"${FILE_SET_ID}"'",
    "deviceIdentifier": "device-serial-or-group-id",
    "runningType": "INSTRUMENTATION",
    "pkgName": "com.example.app",
    "testPkgName": "com.example.app.test",
    "testRunnerName": "androidx.test.runner.AndroidJUnitRunner",
    "testScope": "TEST_APP",
    "testTimeOutSec": 1800,
    "frameworkType": "JUnit4",
    "skipInstall": false,
    "needUninstall": true,
    "needClearData": true,
    "disableRecording": false,
    "pipelineLink": "'"${CI_PIPELINE_URL}"'"
  }'
```

**Response:**
```json
{
  "code": 200,
  "content": {
    "testTaskId": "test-task-uuid-67890",
    "devices": "device-serial-123",
    "message": "Test task started successfully"
  }
}
```

#### 1.3 Poll Test Status

```bash
# Poll until test completes
TEST_TASK_ID="test-task-uuid-67890"

while true; do
  response=$(curl -s -X GET "http://<hydralab-center-url>/api/test/task/${TEST_TASK_ID}" \
    -H "Authorization: Bearer ${HYDRALAB_AUTH_TOKEN}")
  
  status=$(echo $response | jq -r '.content.status')
  
  if [ "$status" = "finished" ] || [ "$status" = "error" ] || [ "$status" = "canceled" ]; then
    break
  fi
  
  echo "Test status: $status"
  sleep 30
done

# Check final results
totalTests=$(echo $response | jq -r '.content.totalTestCount')
failedTests=$(echo $response | jq -r '.content.totalFailCount')

echo "Total tests: $totalTests, Failed: $failedTests"

if [ "$failedTests" -gt 0 ]; then
  exit 1
fi
```

---

### Method 2: Gradle Plugin

The Gradle plugin simplifies HydraLab integration for Android projects.

#### 2.1 Setup build.gradle

```groovy
buildscript {
    repositories {
        mavenCentral()
    }
    dependencies {
        classpath "com.microsoft.hydralab:client:1.23.0"
    }
}

apply plugin: 'com.microsoft.hydralab.client'
```

#### 2.2 Configure gradle.properties

```properties
# HydraLab Configuration
hydraLabAPISchema=https
hydraLabAPIHost=your-hydralab-center.com
hydraLabAPIContextPath=
hydraLabAuthToken=${HYDRALAB_AUTH_TOKEN}

# Test Configuration
deviceIdentifier=device-serial-or-group-id
runningType=INSTRUMENTATION
pkgName=com.example.app
testPkgName=com.example.app.test
testRunnerName=androidx.test.runner.AndroidJUnitRunner
testSuiteName=com.example.app.test.MainTestSuite
testScope=TEST_APP
frameworkType=JUnit4
runTimeOutSeconds=1800

# Build Artifacts
appPath=app/build/outputs/apk/release/app-release.apk
testAppPath=app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk

# Options
skipInstall=false
needUninstall=true
needClearData=true
disableRecording=false
teamName=YourTeam
```

#### 2.3 Run Tests

```bash
# Build and run tests
./gradlew clean assembleRelease assembleAndroidTest
./gradlew requestHydraLabTest
```

**Alternative: YAML Configuration**

Create `testSpec.yml`:

```yaml
apiConfig:
  schema: https
  host: your-hydralab-center.com
  authToken: ${HYDRALAB_AUTH_TOKEN}

testConfig:
  deviceIdentifier: device-serial-123
  runningType: INSTRUMENTATION
  pkgName: com.example.app
  testPkgName: com.example.app.test
  testRunnerName: androidx.test.runner.AndroidJUnitRunner
  testScope: TEST_APP
  frameworkType: JUnit4
  runTimeOutSeconds: 1800
  teamName: YourTeam
  
  appPath: app/build/outputs/apk/release/app-release.apk
  testAppPath: app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
```

Run with:
```bash
./gradlew requestHydraLabTest -PymlConfigFile=testSpec.yml
```

---

### Method 3: Azure DevOps Extension

HydraLab provides a native Azure DevOps extension.

#### 3.1 Install Extension

1. Navigate to Azure DevOps Marketplace
2. Search for "HydraLab"
3. Install to your organization

#### 3.2 Create Service Connection

1. Go to Project Settings → Service Connections
2. Create new Generic Service Connection
3. Set:
   - **Server URL**: `http://your-hydralab-center.com`
   - **API Token**: Your HydraLab auth token
   - **Service Connection Name**: `HydraLabConnection`

#### 3.3 Add Pipeline Task

```yaml
# azure-pipelines.yml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
- task: Gradle@2
  displayName: 'Build APKs'
  inputs:
    workingDirectory: ''
    gradleWrapperFile: 'gradlew'
    tasks: 'clean assembleRelease assembleAndroidTest'

- task: HydraLabDeployTest@1
  displayName: 'Run HydraLab Tests'
  inputs:
    serviceEndpoint: 'HydraLabConnection'
    teamName: 'YourTeam'
    runningType: 'INSTRUMENTATION'
    pkgPath: 'app/build/outputs/apk/release/app-release.apk'
    testPkgPath: 'app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk'
    pkgName: 'com.example.app'
    testPkgName: 'com.example.app.test'
    testSuiteClass: ''
    deviceIdentifier: 'device-serial-123'
    timeoutSec: '1800'
    runningInfo: 'pipeline'
```

---

## Complete Workflow

### Full CI Script Example (Bash)

```bash
#!/bin/bash
set -e

# Configuration
HYDRALAB_URL="http://your-hydralab-center.com"
AUTH_TOKEN="${HYDRALAB_AUTH_TOKEN}"
APP_APK="app/build/outputs/apk/release/app-release.apk"
TEST_APK="app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
DEVICE_ID="${DEVICE_ID:-G.CI}"  # Use device group for CI
TEAM_NAME="${TEAM_NAME:-Default}"

echo "=== HydraLab CI Test Execution ==="

# Step 1: Check HydraLab availability
echo "Checking HydraLab center..."
curl -f -s "${HYDRALAB_URL}/api/center/isAlive" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" > /dev/null || {
  echo "Error: HydraLab center is not available"
  exit 1
}
echo "✓ HydraLab center is alive"

# Step 2: Upload packages
echo "Uploading test packages..."
upload_response=$(curl -s -X POST "${HYDRALAB_URL}/api/package/add" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -F "appFile=@${APP_APK}" \
  -F "testAppFile=@${TEST_APK}" \
  -F "teamName=${TEAM_NAME}" \
  -F "commitId=${GIT_COMMIT:-unknown}" \
  -F "commitCount=${BUILD_NUMBER:-0}" \
  -F "commitMessage=${COMMIT_MESSAGE:-CI Build}")

FILE_SET_ID=$(echo "$upload_response" | jq -r '.content.id')

if [ -z "$FILE_SET_ID" ] || [ "$FILE_SET_ID" = "null" ]; then
  echo "Error: Failed to upload packages"
  echo "$upload_response"
  exit 1
fi
echo "✓ Packages uploaded, fileSetId: ${FILE_SET_ID}"

# Step 3: Trigger test
echo "Triggering test execution..."
test_response=$(curl -s -X POST "${HYDRALAB_URL}/api/test/task/run" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "fileSetId": "'"${FILE_SET_ID}"'",
    "deviceIdentifier": "'"${DEVICE_ID}"'",
    "runningType": "INSTRUMENTATION",
    "pkgName": "com.example.app",
    "testPkgName": "com.example.app.test",
    "testRunnerName": "androidx.test.runner.AndroidJUnitRunner",
    "testScope": "TEST_APP",
    "testTimeOutSec": 1800,
    "frameworkType": "JUnit4",
    "needUninstall": true,
    "needClearData": true,
    "pipelineLink": "'"${CI_PIPELINE_URL:-}"'"
  }')

TEST_TASK_ID=$(echo "$test_response" | jq -r '.content.testTaskId')

if [ -z "$TEST_TASK_ID" ] || [ "$TEST_TASK_ID" = "null" ]; then
  echo "Error: Failed to trigger test"
  echo "$test_response"
  exit 1
fi
echo "✓ Test started, taskId: ${TEST_TASK_ID}"

# Step 4: Wait for test completion
echo "Waiting for test completion..."
max_wait=2000  # seconds
elapsed=0
sleep_interval=30

while [ $elapsed -lt $max_wait ]; do
  status_response=$(curl -s -X GET "${HYDRALAB_URL}/api/test/task/${TEST_TASK_ID}" \
    -H "Authorization: Bearer ${AUTH_TOKEN}")
  
  status=$(echo "$status_response" | jq -r '.content.status // .content.message')
  
  if [ "$status" = "finished" ]; then
    echo "✓ Test finished"
    break
  elif [ "$status" = "error" ]; then
    echo "✗ Test failed with error"
    exit 1
  elif [ "$status" = "canceled" ]; then
    echo "✗ Test was canceled"
    exit 1
  fi
  
  echo "Test status: ${status} (${elapsed}s elapsed)"
  sleep $sleep_interval
  elapsed=$((elapsed + sleep_interval))
done

if [ $elapsed -ge $max_wait ]; then
  echo "✗ Test timed out"
  exit 1
fi

# Step 5: Check results
echo "Checking test results..."
total_tests=$(echo "$status_response" | jq -r '.content.totalTestCount')
failed_tests=$(echo "$status_response" | jq -r '.content.totalFailCount')

echo "Total tests: ${total_tests}"
echo "Failed tests: ${failed_tests}"

# Generate report URL
report_url="${HYDRALAB_URL}/portal/index.html?redirectUrl=/info/task/${TEST_TASK_ID}"
echo "Test report: ${report_url}"

if [ "$failed_tests" -gt 0 ]; then
  echo "✗ Tests failed"
  exit 1
fi

echo "✓ All tests passed"
```

---

## CI/CD Examples

### GitHub Actions

```yaml
# .github/workflows/hydralab-test.yml
name: HydraLab Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up JDK 11
      uses: actions/setup-java@v3
      with:
        java-version: '11'
        distribution: 'temurin'
    
    - name: Build APKs
      run: |
        ./gradlew clean assembleRelease assembleAndroidTest
    
    - name: Upload to HydraLab
      id: upload
      env:
        HYDRALAB_TOKEN: ${{ secrets.HYDRALAB_AUTH_TOKEN }}
      run: |
        response=$(curl -s -X POST "${{ vars.HYDRALAB_URL }}/api/package/add" \
          -H "Authorization: Bearer ${HYDRALAB_TOKEN}" \
          -F "appFile=@app/build/outputs/apk/release/app-release.apk" \
          -F "testAppFile=@app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk" \
          -F "teamName=${{ vars.TEAM_NAME }}" \
          -F "commitId=${{ github.sha }}" \
          -F "commitMessage=${{ github.event.head_commit.message }}")
        
        fileSetId=$(echo "$response" | jq -r '.content.id')
        echo "FILE_SET_ID=$fileSetId" >> $GITHUB_OUTPUT
    
    - name: Run Tests
      env:
        HYDRALAB_TOKEN: ${{ secrets.HYDRALAB_AUTH_TOKEN }}
        FILE_SET_ID: ${{ steps.upload.outputs.FILE_SET_ID }}
      run: |
        bash scripts/run-hydralab-test.sh
```

### GitLab CI

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test

variables:
  HYDRALAB_URL: "http://your-hydralab-center.com"

build:
  stage: build
  image: mingc/android-build-box:latest
  script:
    - ./gradlew clean assembleRelease assembleAndroidTest
  artifacts:
    paths:
      - app/build/outputs/apk/

test:
  stage: test
  image: curlimages/curl:latest
  dependencies:
    - build
  script:
    - apk add --no-cache jq bash
    - export HYDRALAB_AUTH_TOKEN="${HYDRALAB_TOKEN}"
    - export GIT_COMMIT="${CI_COMMIT_SHA}"
    - export BUILD_NUMBER="${CI_PIPELINE_ID}"
    - export COMMIT_MESSAGE="${CI_COMMIT_MESSAGE}"
    - bash scripts/run-hydralab-test.sh
  only:
    - main
    - develop
```

### Jenkins

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        HYDRALAB_URL = 'http://your-hydralab-center.com'
        HYDRALAB_TOKEN = credentials('hydralab-auth-token')
    }
    
    stages {
        stage('Build') {
            steps {
                sh './gradlew clean assembleRelease assembleAndroidTest'
            }
        }
        
        stage('Upload to HydraLab') {
            steps {
                script {
                    def response = sh(
                        script: """
                            curl -s -X POST "${HYDRALAB_URL}/api/package/add" \
                              -H "Authorization: Bearer ${HYDRALAB_TOKEN}" \
                              -F "appFile=@app/build/outputs/apk/release/app-release.apk" \
                              -F "testAppFile=@app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk" \
                              -F "teamName=YourTeam" \
                              -F "commitId=${GIT_COMMIT}" \
                              -F "commitMessage=${env.GIT_COMMIT_MESSAGE}"
                        """,
                        returnStdout: true
                    ).trim()
                    
                    def json = readJSON text: response
                    env.FILE_SET_ID = json.content.id
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'bash scripts/run-hydralab-test.sh'
            }
        }
    }
    
    post {
        always {
            echo "Test report: ${HYDRALAB_URL}/portal/index.html?redirectUrl=/info/task/${TEST_TASK_ID}"
        }
    }
}
```

---

## Test Configuration Options

### Running Types

| Type | Description | Use Case |
|------|-------------|----------|
| `INSTRUMENTATION` | Android Espresso/JUnit tests | UI and integration tests |
| `APPIUM` | Appium-based tests | Cross-platform automated tests |
| `APPIUM_CROSS` | Multi-platform Appium | iOS + Android tests |
| `SMART` | AI-powered exploratory testing | Automated exploration |
| `APPIUM_MONKEY` | Monkey stress testing | Stability testing |
| `MAESTRO` | Maestro flow tests | BDD-style mobile tests |
| `T2C_JSON` | Taps-to-cases JSON tests | Replay recorded interactions |

### Device Identifiers

**Single Device:**
```json
"deviceIdentifier": "ce0617166b244c630d7e"
```

**Device Group:**
```json
"deviceIdentifier": "G.CI-Devices"
```

Use device groups for parallel execution across multiple devices.

### Test Scope Options

| Scope | Description |
|-------|-------------|
| `TEST_APP` | Run all tests in test APK |
| `CLASS` | Run specific test class (requires `testSuiteClass`) |
| `PACKAGE` | Run tests in specific package |

### Common Parameters

```json
{
  "testTimeOutSec": 1800,           // Max test duration
  "skipInstall": false,              // Skip APK installation
  "needUninstall": true,             // Uninstall before test
  "needClearData": true,             // Clear app data
  "disableRecording": false,         // Enable video recording
  "enableNetworkMonitor": false,     // Monitor network traffic
  "enableTestOrchestrator": false,   // Use AndroidX Test Orchestrator
  "deviceTestCount": 1,              // Number of test iterations
  "neededPermissions": ["CAMERA", "LOCATION"],  // Grant permissions
  "testRunArgs": {                   // Instrumentation arguments
    "clearPackageData": "true"
  }
}
```

---

## Troubleshooting

### Common Issues

**1. Authentication Failed (401)**
- Verify token is valid: `curl -H "Authorization: Bearer ${TOKEN}" ${URL}/api/center/isAlive`
- Regenerate token if expired
- Check token has correct permissions

**2. Device Not Found**
- List available devices: `GET /api/device/list`
- Ensure device is online and connected to agent
- Use device groups (G.xxx) for CI environments

**3. File Upload Fails**
- Check file size limits
- Verify APK files are valid
- Ensure sufficient storage on HydraLab center

**4. Test Timeout**
- Increase `testTimeOutSec` value
- Check device availability during test
- Review test logs in HydraLab portal

**5. Test Queue Wait Time**
- Use dedicated CI device groups
- Check queue status: `GET /api/test/task/queue`
- Consider adding more devices to agent pool

---

## Best Practices

1. **Use Device Groups for CI**
   - Create dedicated device groups (e.g., `G.CI`, `G.Nightly`)
   - Configure groups with appropriate test types

2. **Implement Proper Retry Logic**
   - Retry failed uploads/triggers with exponential backoff
   - Handle transient network errors

3. **Monitor Test Results**
   - Parse JSON responses for pass/fail status
   - Download test artifacts (videos, logs) for failed tests
   - Set appropriate CI exit codes

4. **Optimize Build Artifacts**
   - Use release/production APKs when possible
   - Keep test APKs minimal and focused

5. **Security**
   - Never commit auth tokens
   - Rotate tokens regularly
   - Use team-specific tokens with appropriate permissions

6. **Performance**
   - Run tests in parallel using device groups
   - Use `groupTestType: SINGLE` for independent tests
   - Archive test results for historical analysis

---

## Additional Resources

- **Official Documentation**: https://github.com/microsoft/HydraLab/wiki
- **API Swagger Docs**: `http://<hydralab-url>/v3/api-docs`
- **Gradle Plugin**: https://github.com/microsoft/HydraLab/tree/main/gradle_plugin
- **Release Notes**: https://github.com/microsoft/HydraLab/wiki/Release-Notes

---

## Summary

HydraLab provides comprehensive CLI/API support for CI integration through:
- **REST APIs** for direct integration
- **Gradle Plugin** for Android projects
- **Azure DevOps Extension** for Microsoft environments

Choose the method that best fits your CI/CD pipeline and follow the authentication and workflow patterns outlined in this guide.

**Key Workflow Steps:**
1. Generate authentication token
2. Upload app and test packages → Get `fileSetId`
3. Trigger test run → Get `testTaskId`
4. Poll test status until completion
5. Parse results and set CI exit code

For CI automation, manual portal uploads are completely unnecessary.
