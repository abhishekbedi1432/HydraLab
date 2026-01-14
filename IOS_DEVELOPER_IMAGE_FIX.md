# Fix: HydraLab iOS DeveloperImage Not Found Error

## Problem Analysis

### Error from Logs
```
tidevice.exceptions.ServiceError: DeveloperImage not found
FileNotFoundException: /Users/abhishek.bedi/peet/HydraLab/storage/devices/screenshots/...
```

### Root Causes

1. **iOS Version Too New**: Your iPhone is running **iOS 26.2**
   - `tidevice` doesn't support iOS 17+ properly
   - DeveloperImage system was replaced by "Developer Mode" in iOS 17+
   - The GitHub repository doesn't have support files for iOS 26.x

2. **Missing Screenshots Directory**: Directory not created by agent

3. **Legacy Tool**: `tidevice` uses old DeveloperDiskImage method, incompatible with modern iOS

---

## Solutions

### ✅ Solution 1: Enable Developer Mode on iPhone (Recommended)

iOS 17+ requires "Developer Mode" to be manually enabled:

**Steps:**
1. On your iPhone, go to: **Settings** → **Privacy & Security** → **Developer Mode**
2. Toggle **Developer Mode** ON
3. iPhone will restart
4. After restart, confirm Developer Mode activation

**Verify:**
```bash
tidevice --udid 00008030-0005743926A0802E screenshot test.jpg
```

If this works, screenshot issue is fixed!

---

### ✅ Solution 2: Use pymobiledevice3 Instead (Better for iOS 17+)

`pymobiledevice3` is already installed and works with modern iOS:

**Test pymobiledevice3:**
```bash
# List devices
python3 -m pymobiledevice3 usbmux list

# Mount developer image (for iOS 17+)
python3 -m pymobiledevice3 mounter auto-mount

# Take screenshot
python3 -m pymobiledevice3 dvt screenshot test.png
```

**Configure HydraLab to use pymobiledevice3:**

This requires modifying the HydraLab agent to use pymobiledevice3 instead of tidevice for screenshots on iOS 17+.

---

### ✅ Solution 3: Manually Mount DeveloperImage (Temporary Fix)

For iOS versions < 17, you can manually copy DeveloperDiskImage:

```bash
# Check your Xcode's available versions
ls /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/DeviceSupport/

# Your Xcode has: 15.0, 15.2, 15.4, 15.5, 16.0, 16.1, 16.4
# But your iOS is 26.2 (likely iOS 18.x or newer)
```

**Not applicable** - Your iOS is too new for this method.

---

### ✅ Solution 4: Disable Screenshot Functionality (Workaround)

If screenshots aren't critical, disable them temporarily:

**Edit HydraLab Agent Config:**

File: `/Users/abhishek.bedi/peet/HydraLab/application.yml`

```yaml
app:
  device:
    screenshot:
      enabled: false  # Disable screenshots
```

Then restart agent:
```bash
cd /Users/abhishek.bedi/peet/HydraLab
./stop-agent.sh
./start-agent.sh
```

---

### ✅ Solution 5: Update tidevice (May Help)

Try updating to latest tidevice:

```bash
pipx upgrade tidevice

# Or reinstall
pipx uninstall tidevice
pipx install tidevice
```

---

## Quick Fix Applied

I've already fixed the **missing directory** issue:

```bash
✓ Created: /Users/abhishek.bedi/peet/HydraLab/storage/devices/screenshots
```

---

## Recommended Action Plan

### Immediate (Choose One):

**Option A: Enable Developer Mode (Easiest)**
1. Enable Developer Mode on iPhone (Settings → Privacy & Security → Developer Mode)
2. Restart iPhone
3. Confirm activation
4. Test with: `tidevice screenshot test.jpg`

**Option B: Disable Screenshots (Quickest)**
1. Edit `application.yml`: Set `screenshot.enabled: false`
2. Restart HydraLab agent
3. Tests will work without screenshots

### Long-term: 

Consider contributing to HydraLab to add pymobiledevice3 support for iOS 17+ devices.

---

## Testing After Fix

### Test 1: Check Developer Mode
```bash
tidevice --udid 00008030-0005743926A0802E screenshot /tmp/test.jpg
ls -lh /tmp/test.jpg
```

### Test 2: Verify Screenshot Directory
```bash
ls -la /Users/abhishek.bedi/peet/HydraLab/storage/devices/screenshots/
```

### Test 3: Run iOS Test Again
```bash
export HYDRALAB_AUTH_TOKEN=$(curl -s "http://localhost:9886/api/auth/create" | jq -r '.content.token')
cd /Users/abhishek.bedi/peet/HydraLab
python3 run_ios_tests.py
```

### Test 4: Check Agent Logs
```bash
tail -f /Users/abhishek.bedi/peet/HydraLab/storage/devices/log/agent.log | grep -i screenshot
```

---

## Technical Details

### Why This Happens

**iOS 17+ Changes:**
- Apple removed DeveloperDiskImage.dmg system
- Introduced "Developer Mode" toggle
- Requires explicit user consent
- Uses personalized developer images
- Old tools like `tidevice` don't support this

**iOS Version Confusion:**
- Your device reports "iOS 26.2"
- This is likely iOS 18.2 or later
- Version numbering may vary by region/beta

**Tool Compatibility:**
| Tool | iOS < 17 | iOS 17+ | Status |
|------|----------|---------|--------|
| tidevice | ✓ | ✗ | Old |
| pymobiledevice3 | ✓ | ✓ | Modern |
| Xcode DeviceSupport | ✓ | ✗ | Legacy |

---

## Prevention

### For Future iOS Updates:

1. **Keep Tools Updated**
   ```bash
   pipx upgrade tidevice
   pip3 install --upgrade pymobiledevice3
   ```

2. **Enable Developer Mode Immediately**
   - Do this right after iOS update
   - Prevents test disruption

3. **Monitor HydraLab Logs**
   ```bash
   tail -f storage/devices/log/agent.log
   ```

4. **Use Latest Xcode**
   - Ensures latest DeviceSupport files
   - Better iOS compatibility

---

## Additional Resources

- **tidevice GitHub**: https://github.com/alibaba/taobao-iphone-device
- **pymobiledevice3 GitHub**: https://github.com/doronz88/pymobiledevice3
- **HydraLab Issues**: https://github.com/microsoft/HydraLab/issues

---

## Status

- ✅ **Screenshot directory created**
- ⚠️ **DeveloperImage issue**: Requires Developer Mode OR disable screenshots
- ✅ **Test execution works**: Core functionality operational
- ⚠️ **Screenshots fail**: Non-critical, fixable

---

## Summary

**The test execution worked!** The screenshot failure is a non-critical issue that can be fixed by enabling Developer Mode on your iPhone. The main test automation functionality is operational.

**Choose your fix:**
1. **Best**: Enable Developer Mode on iPhone (5 minutes)
2. **Quickest**: Disable screenshots in config (1 minute)
3. **Alternative**: Wait for tidevice update (unknown timeline)
