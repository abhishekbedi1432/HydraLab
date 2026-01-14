# iOS Migration Summary: tidevice → pymobiledevice3

## Migration Status: Foundation Complete ✅

**Branch:** `devops/bedi/hydralabs-aug18-ios-pymobiledevice3`  
**Date:** January 14, 2026  
**Status:** Ready for Implementation

---

## ✅ Completed Tasks

### 1. Git Branch Created
```bash
Branch: devops/bedi/hydralabs-aug18-ios-pymobiledevice3
Based on: devops/bedi/hydralabs-aug18-release
Status: Active
```

### 2. Codebase Analysis Complete
**Files identified for modification:** 16 files
- 6 Java source files
- 3 Shell/PowerShell scripts
- 5 Documentation files  
- 2 Python scripts

**Key files analyzed:**
- ✅ `IOSUtils.java` - 20 tidevice command usages
- ✅ `IOSDeviceDriver.java` - 2 tidevice references
- ✅ Environment capability files
- ✅ Performance inspector files
- ✅ Installation scripts

### 3. Migration Document Created
**File:** `TIDEVICE_TO_PYMOBILEDEVICE3_MIGRATION.md`

**Contents:**
- Complete command mapping (13 commands)
- Implementation details
- File modification list
- Breaking changes documentation
- Testing checklist
- Rollback plan
- Installation requirements
- Known issues and workarounds

---

## 📋 Remaining Tasks

### Phase 1: Core Code Changes (High Priority)

**1. Update IOSUtils.java**
```java
File: common/src/main/java/com/microsoft/hydralab/common/util/IOSUtils.java
Changes needed: ~20 command replacements

Key Methods to Update:
- getIOSDeviceListJsonStr() 
- getIOSDeviceDetailInfo()
- takeScreenshot()
- installApp()
- uninstallApp()
- launchApp()
- stopApp()
- startIOSLog()
- startIOSDeviceWatcher()
- collectCrashInfo()
- proxyWDA()
- killProxyWDA()
- getAppList()
- getMjpegServerPortByUdid()
```

**2. Update IOSDeviceDriver.java**
```java
File: common/src/main/java/com/microsoft/hydralab/common/management/device/impl/IOSDeviceDriver.java

Changes needed:
- Line 50-51: Change version constants
  OLD: MAJOR_TIDEVICE_VERSION = 0, MINOR_TIDEVICE_VERSION = 10
  NEW: Remove (not applicable for pymobiledevice3)

- Line 67: Update kill command
  OLD: ShellUtils.killProcessByCommandStr("tidevice", classLogger);
  NEW: ShellUtils.killProcessByCommandStr("python3 -m pymobiledevice3", classLogger);

- Line 83: Update capability requirement
  OLD: new EnvCapabilityRequirement(EnvCapability.CapabilityKeyword.tidevice, 0, 10)
  NEW: new EnvCapabilityRequirement(EnvCapability.CapabilityKeyword.pymobiledevice3, 0, 0)
```

**3. Update EnvCapability.java**
```java
File: common/src/main/java/com/microsoft/hydralab/common/entity/agent/EnvCapability.java

Add enum value:
public enum CapabilityKeyword {
    ...
    pymobiledevice3,  // ADD THIS
    tidevice,  // KEEP for backwards compatibility checking
    ...
}
```

### Phase 2: Supporting Files (Medium Priority)

**4. Update XCTestRunner.java**
```java
File: agent/src/main/java/com/microsoft/hydralab/agent/runner/xctest/XCTestRunner.java

Line 45: Update requirement
OLD: new EnvCapabilityRequirement(tidevice, 0, 10)
NEW: new EnvCapabilityRequirement(pymobiledevice3, 0, 0)
```

**5. Update Performance Files**
- `IOSPerfTestHelper.java`
- `IOSEnergyGaugeInspector.java`
- `IOSMemoryPerfInspector.java`

Change: Update capability requirements

**6. Update Installation Scripts**
```bash
# MacOS: agent/agent_installer/MacOS/iOS/installer.sh
OLD: pip install tidevice
NEW: pip3 install pymobiledevice3

# Windows: agent/agent_installer/Windows/iOS/installer.ps1
OLD: pip install tidevice
NEW: pip3 install pymobiledevice3
```

**7. Update Startup Scripts**
```bash
# start-agent.sh
# start-center.sh
Update validation checks for pymobiledevice3
```

### Phase 3: Documentation (Low Priority)

**8. Update Documentation Files**
- `README.md`
- `iOS_TEST_EXECUTION_GUIDE.md`
- `IOS_TEST_QUICKSTART.md`
- `IOS_TEST_EXECUTION_SUCCESS.md`
- `IOS_DEVELOPER_IMAGE_FIX.md`
- `run_ios_tests.py`

Change: Replace all `tidevice` references with `pymobiledevice3`

### Phase 4: Build & Test (Critical)

**9. Build Updated Jars**
```bash
./gradlew clean
./gradlew :center:bootJar :agent:bootJar
```

**10. Test on iPhone 11 Pro (iOS 26.2)**
- [ ] Device discovery
- [ ] Screenshot capture
- [ ] App installation
- [ ] iOS test execution
- [ ] Log collection
- [ ] Performance monitoring

---

## 🔧 Quick Implementation Guide

### Step-by-Step Code Update

**Method 1: Manual Updates (Recommended for Review)**

1. Open each Java file in your IDE
2. Use Find & Replace with the migration document as reference
3. Update commands according to mapping table
4. Review each change for context

**Method 2: Automated Script (Faster)**

Create a replacement script:
```bash
#!/bin/bash
# This would need careful testing before running
# Example replacements (simplified):

# IOSUtils.java
sed -i '' 's/tidevice list --json/python3 -m pymobiledevice3 usbmux list --json/g' common/src/main/java/com/microsoft/hydralab/common/util/IOSUtils.java

# Add similar sed commands for other files...
```

**Method 3: IDE Refactoring**

1. Use IntelliJ IDEA or Eclipse
2. Structural Search & Replace
3. Create patterns for tidevice commands
4. Replace with pymobiledevice3 equivalents

---

## 📊 Command Mapping Quick Reference

```bash
# Device List
tidevice list --json
→ python3 -m pymobiledevice3 usbmux list

# Device Info
tidevice -u <udid> info --json
→ python3 -m pymobiledevice3 lockdown info -u <udid> --json

# Screenshot
tidevice -u <udid> screenshot <path>
→ python3 -m pymobiledevice3 developer dvt screenshot -u <udid> <path>

# Install App
tidevice -u <udid> install <path>
→ python3 -m pymobiledevice3 apps install -u <udid> <path>

# Uninstall App
tidevice -u <udid> uninstall <bundle>
→ python3 -m pymobiledevice3 apps uninstall -u <udid> <bundle>

# Launch App
tidevice -u <udid> launch <bundle>
→ python3 -m pymobiledevice3 developer dvt launch -u <udid> <bundle>

# Kill App
tidevice -u <udid> kill <bundle>
→ python3 -m pymobiledevice3 developer dvt kill -u <udid> <bundle>

# System Log
tidevice -u <udid> syslog
→ python3 -m pymobiledevice3 syslog live -u <udid>

# Crash Report
tidevice -u <udid> crashreport <folder>
→ python3 -m pymobiledevice3 crash pull -u <udid> <folder>

# Port Relay
tidevice -u <udid> relay <port1> <port2>
→ python3 -m pymobiledevice3 remote start-tunnel -u <udid> <port1>:<port2>

# Device Watch
tidevice watch
→ python3 -m pymobiledevice3 usbmux watch

# App List
tidevice -u <udid> applist
→ python3 -m pymobiledevice3 apps list -u <udid>
```

---

## ⚠️ Important Notes

### JSON Output Changes

**tidevice** returns combined device info:
```json
{
  "udid": "xxx",
  "name": "iPhone",
  "market_name": "iPhone 11 Pro",
  "product_version": "26.2"
}
```

**pymobiledevice3** requires two steps:
```json
// Step 1: usbmux list
{"SerialNumber": "xxx", "ConnectionType": "USB"}

// Step 2: lockdown info
{"DeviceName": "iPhone", "ProductVersion": "26.2", ...}
```

**Impact:** `IOSDeviceDriver.parseJsonToDevice()` and `updateDeviceDetailByUdid()` need significant updates.

### Process Kill Logic

Old pattern:
```java
ShellUtils.killProcessByCommandStr("tidevice", logger);
```

New pattern:
```java
ShellUtils.killProcessByCommandStr("python3 -m pymobiledevice3", logger);
```

### Error Handling

pymobiledevice3 has different error messages:
- `TunneldError` instead of `MuxServiceError`
- `InvalidServiceError` warnings (expected for iOS 17+)

---

## 🧪 Testing Strategy

### Pre-Merge Testing

**1. Unit Tests**
- Test command construction
- Test output parsing
- Test error handling

**2. Integration Tests**
- Device discovery flow
- Screenshot capture
- App lifecycle (install/launch/kill/uninstall)

**3. End-to-End Tests**
- Complete iOS test execution
- XCTest runner
- Performance monitoring
- Log collection

### Test Devices

- [ ] iOS 14.x device
- [ ] iOS 15.x device
- [ ] iOS 16.x device
- [x] iOS 17+ device (iPhone 11 Pro - iOS 26.2)
- [ ] iPad

### Test Scenarios

- [ ] Single device test
- [ ] Multiple devices simultaneously
- [ ] Device connect/disconnect during test
- [ ] WDA proxy and port relay
- [ ] Screen recording
- [ ] Crash report collection
- [ ] System log collection
- [ ] Performance metrics collection

---

## 🚀 Deployment Plan

### Stage 1: Development Testing (Current)
- Complete code changes
- Local testing on dev machine
- Fix any issues found

### Stage 2: Beta Testing
- Deploy to staging environment
- Test with QA team
- Collect feedback

### Stage 3: Production Rollout
- Merge to main branch
- Update CI/CD pipelines
- Monitor for issues
- Document any new findings

---

## 📝 Next Steps for Implementation

**Immediate (This Session):**
1. ✅ Create migration branch
2. ✅ Analyze codebase
3. ✅ Create migration document
4. ⏳ Update core Java files (IOSUtils.java, IOSDeviceDriver.java)
5. ⏳ Update capability requirements
6. ⏳ Build and basic test

**Short Term (Next 1-2 Days):**
1. Complete all code changes
2. Update installation scripts
3. Update documentation
4. Comprehensive testing on iOS 26.2
5. Fix any bugs found

**Medium Term (Next Week):**
1. Test on multiple iOS versions
2. Performance testing
3. Code review
4. Update CI/CD pipelines
5. Prepare for merge

---

## 📚 Resources

**Created Documents:**
- ✅ `TIDEVICE_TO_PYMOBILEDEVICE3_MIGRATION.md` - Complete migration guide
- ✅ `IOS_MIGRATION_SUMMARY.md` - This summary
- ✅ `IOS_DEVELOPER_IMAGE_FIX.md` - Background on the issue
- ✅ `run_ios_tests.py` - Test script (already using pymobiledevice3)

**External Resources:**
- [pymobiledevice3 GitHub](https://github.com/doronz88/pymobiledevice3)
- [pymobiledevice3 Documentation](https://pymobiledevice3.readthedocs.io/)
- [HydraLab Wiki](https://github.com/microsoft/HydraLab/wiki)

---

## 🎯 Success Criteria

✅ **Code Quality:**
- All tidevice references replaced
- No compilation errors
- Code follows existing patterns
- Proper error handling

✅ **Functionality:**
- All iOS operations work
- Screenshots succeed on iOS 17+
- Tests pass on iOS 26.2
- Performance acceptable

✅ **Documentation:**
- Migration guide complete
- All docs updated
- Code comments added
- README updated

✅ **Testing:**
- Unit tests pass
- Integration tests pass
- Manual testing successful
- No regressions found

---

## 🔄 Current State

```
Branch: devops/bedi/hydralabs-aug18-ios-pymobiledevice3
Status: Ready for code implementation
Files staged: TIDEVICE_TO_PYMOBILEDEVICE3_MIGRATION.md
Next: Begin code modifications
```

---

## 💡 Recommendations

1. **Phased Approach**: Implement core files first, test, then proceed to supporting files
2. **Incremental Commits**: Commit after each logical group of changes
3. **Test Early**: Test after each major file modification
4. **Keep Documentation Updated**: Update migration doc with any deviations from plan
5. **Backup**: Keep original branch accessible for comparison

---

## 📞 Support

For questions or issues during implementation:
1. Refer to migration document
2. Check pymobiledevice3 documentation
3. Test commands manually with `python3 -m pymobiledevice3 --help`
4. Review agent logs for specific errors

---

**Ready to proceed with code implementation!** 🚀
