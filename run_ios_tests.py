#!/usr/bin/env python3
"""
HydraLab iOS Test Runner
Automated CLI tool to run iOS XCTest tests on HydraLab
"""

import os
import sys
import time
import json
import subprocess
import zipfile
from pathlib import Path
from typing import Optional, Dict, Any
import requests
from datetime import datetime


class Colors:
    """ANSI color codes for terminal output"""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


class HydraLabIOSTestRunner:
    """Runner for iOS tests on HydraLab"""
    
    def __init__(self, hydralab_url: str = "http://localhost:9886", 
                 test_file: str = "/Users/abhishek.bedi/Downloads/ios_tests.zip",
                 team_name: str = "Default"):
        self.hydralab_url = hydralab_url.rstrip('/')
        self.test_file = test_file
        self.team_name = team_name
        self.auth_token = os.getenv('HYDRALAB_AUTH_TOKEN')
        self.device_udid = None
        self.device_name = None
        self.device_model = None
        
    def print_header(self, text: str):
        """Print section header"""
        print(f"\n{Colors.BOLD}{'=' * 70}{Colors.RESET}")
        print(f"{Colors.BOLD}{text}{Colors.RESET}")
        print(f"{Colors.BOLD}{'=' * 70}{Colors.RESET}")
        
    def print_success(self, text: str):
        """Print success message"""
        print(f"{Colors.GREEN}✓ {text}{Colors.RESET}")
        
    def print_error(self, text: str):
        """Print error message"""
        print(f"{Colors.RED}✗ {text}{Colors.RESET}")
        
    def print_warning(self, text: str):
        """Print warning message"""
        print(f"{Colors.YELLOW}⚠ {text}{Colors.RESET}")
        
    def print_info(self, text: str):
        """Print info message"""
        print(f"{Colors.BLUE}ℹ {text}{Colors.RESET}")
        
    def detect_ios_device(self) -> bool:
        """Detect connected iOS device using tidevice"""
        self.print_header("Detecting iOS Devices")
        
        try:
            result = subprocess.run(['tidevice', 'list'], 
                                  capture_output=True, text=True, check=True)
            
            lines = result.stdout.strip().split('\n')
            if len(lines) < 2:
                self.print_error("No iOS device found")
                print("Please connect an iOS device and ensure it's trusted")
                print("Run: tidevice list")
                return False
            
            # Parse device info (skip header)
            device_line = lines[1].split()
            self.device_udid = device_line[0]
            self.device_name = device_line[2]
            self.device_model = ' '.join(device_line[3:6]) if len(device_line) > 3 else "iPhone"
            
            self.print_success("Found iOS device:")
            print(f"  - Name: {self.device_name}")
            print(f"  - Model: {self.device_model}")
            print(f"  - UDID: {self.device_udid}")
            return True
            
        except subprocess.CalledProcessError as e:
            self.print_error(f"Failed to detect iOS device: {e}")
            print("Make sure 'tidevice' is installed: pip install tidevice")
            return False
        except FileNotFoundError:
            self.print_error("'tidevice' command not found")
            print("Install it with: pip install tidevice")
            return False
            
    def check_auth_token(self) -> bool:
        """Check if authentication token is set"""
        if not self.auth_token:
            self.print_error("HYDRALAB_AUTH_TOKEN not set!")
            print("\nTo generate a token:")
            print("1. Open: http://localhost:9886/portal/index.html#/auth")
            print("2. Login and click 'Create Token'")
            print("3. Export the token:")
            print("   export HYDRALAB_AUTH_TOKEN='your-token-here'")
            return False
        return True
        
    def check_hydralab_center(self) -> bool:
        """Check if HydraLab center is accessible"""
        self.print_header("Checking HydraLab Center")
        
        try:
            response = requests.get(f"{self.hydralab_url}/api/center/info", timeout=10)
            response.raise_for_status()
            data = response.json()
            
            if data.get('code') != 200:
                self.print_error(f"HydraLab center returned error code: {data.get('code')}")
                return False
                
            version = data.get('content', {}).get('versionName', 'unknown')
            self.print_success(f"HydraLab Center is running (version: {version})")
            return True
            
        except requests.exceptions.RequestException as e:
            self.print_error(f"Cannot connect to HydraLab center at {self.hydralab_url}")
            print(f"Error: {e}")
            return False
            
    def verify_test_package(self) -> Optional[Dict[str, str]]:
        """Verify test package and extract metadata"""
        self.print_header("Verifying Test Package")
        
        test_path = Path(self.test_file)
        if not test_path.exists():
            self.print_error(f"Test file not found: {self.test_file}")
            return None
            
        file_size = test_path.stat().st_size
        size_mb = file_size / (1024 * 1024)
        self.print_success(f"Test file found: {self.test_file} ({size_mb:.1f} MB)")
        
        # Extract and verify contents
        try:
            with zipfile.ZipFile(test_path, 'r') as zip_ref:
                file_list = zip_ref.namelist()
                
                # Find .app
                app_files = [f for f in file_list if '.app/' in f and not f.endswith('/')]
                if not app_files:
                    self.print_error("No .app found in test package")
                    return None
                    
                app_path = app_files[0].split('.app/')[0] + '.app'
                app_name = Path(app_path).name
                self.print_success(f"Found iOS app: {app_name}")
                
                # Find .xctest
                xctest_files = [f for f in file_list if '.xctest/' in f and not f.endswith('/')]
                if xctest_files:
                    xctest_path = xctest_files[0].split('.xctest/')[0] + '.xctest'
                    xctest_name = Path(xctest_path).stem
                    self.print_success(f"Found XCTest bundle: {xctest_name}")
                else:
                    # Check for xctest in PlugIns
                    plugin_tests = [f for f in file_list if 'PlugIns/' in f and '.xctest' in f]
                    if plugin_tests:
                        xctest_path = [f for f in plugin_tests if '.xctest/' in f][0]
                        xctest_name = Path(xctest_path.split('.xctest/')[0]).stem
                        self.print_success(f"Found XCTest bundle (embedded): {xctest_name}")
                    else:
                        xctest_name = "RunnerTests"
                        self.print_warning(f"No XCTest bundle found, using default: {xctest_name}")
                
                return {
                    'app_name': app_name,
                    'xctest_name': xctest_name,
                    'pkg_name': xctest_name
                }
                
        except zipfile.BadZipFile:
            self.print_error("Invalid ZIP file")
            return None
        except Exception as e:
            self.print_error(f"Error verifying test package: {e}")
            return None
            
    def upload_test_package(self) -> Optional[str]:
        """Upload test package to HydraLab"""
        self.print_header("Uploading Test Package")
        
        headers = {'Authorization': f'Bearer {self.auth_token}'}
        
        commit_id = os.getenv('GIT_COMMIT', f"ios-test-{datetime.now().strftime('%Y%m%d-%H%M%S')}")
        commit_count = os.getenv('BUILD_NUMBER', '1')
        
        files = {'appFile': open(self.test_file, 'rb')}
        data = {
            'teamName': self.team_name,
            'commitId': commit_id,
            'commitCount': commit_count,
            'commitMessage': 'iOS Test Run from CLI'
        }
        
        try:
            response = requests.post(
                f"{self.hydralab_url}/api/package/add",
                headers=headers,
                files=files,
                data=data,
                timeout=120
            )
            response.raise_for_status()
            result = response.json()
            
            if result.get('code') != 200:
                self.print_error(f"Upload failed: {result.get('message', 'Unknown error')}")
                return None
                
            file_set_id = result.get('content', {}).get('id')
            pkg_name = result.get('content', {}).get('packageName', 'RunnerTests')
            
            self.print_success("Package uploaded successfully")
            print(f"  - File Set ID: {file_set_id}")
            print(f"  - Package Name: {pkg_name}")
            
            return file_set_id
            
        except requests.exceptions.RequestException as e:
            self.print_error(f"Failed to upload package: {e}")
            return None
        finally:
            files['appFile'].close()
            
    def trigger_test_run(self, file_set_id: str, test_info: Dict[str, str]) -> Optional[str]:
        """Trigger test execution on HydraLab"""
        self.print_header("Triggering Test Execution")
        
        headers = {
            'Authorization': f'Bearer {self.auth_token}',
            'Content-Type': 'application/json'
        }
        
        test_config = {
            'fileSetId': file_set_id,
            'deviceIdentifier': self.device_udid,
            'runningType': 'XCTEST',
            'pkgName': test_info.get('pkg_name', 'RunnerTests'),
            'testPkgName': test_info.get('xctest_name', 'RunnerTests'),
            'testTimeOutSec': 900,
            'frameworkType': 'XCTest',
            'skipInstall': False,
            'needUninstall': True,
            'needClearData': True,
            'disableRecording': False,
            'disableGifEncoder': False,
            'pipelineLink': 'CLI Test Run',
            'deviceTestCount': 1
        }
        
        print("Test configuration:")
        print(json.dumps(test_config, indent=2))
        print()
        
        try:
            response = requests.post(
                f"{self.hydralab_url}/api/test/task/run",
                headers=headers,
                json=test_config,
                timeout=30
            )
            response.raise_for_status()
            result = response.json()
            
            if result.get('code') != 200:
                self.print_error(f"Failed to trigger test: {result.get('message', 'Unknown error')}")
                return None
                
            test_task_id = result.get('content', {}).get('testTaskId')
            devices = result.get('content', {}).get('devices', 'none')
            message = result.get('content', {}).get('message', '')
            
            self.print_success("Test task started")
            print(f"  - Task ID: {test_task_id}")
            print(f"  - Device: {devices}")
            if message:
                print(f"  - Message: {message}")
                
            return test_task_id
            
        except requests.exceptions.RequestException as e:
            self.print_error(f"Failed to trigger test: {e}")
            return None
            
    def monitor_test_execution(self, test_task_id: str) -> Optional[Dict[str, Any]]:
        """Monitor test execution and wait for completion"""
        self.print_header("Monitoring Test Execution")
        
        print(f"Watch progress: {self.hydralab_url}/portal/index.html#/device")
        print(f"Test report: {self.hydralab_url}/portal/index.html?redirectUrl=/info/task/{test_task_id}")
        print()
        
        headers = {'Authorization': f'Bearer {self.auth_token}'}
        max_wait = 1000  # seconds
        elapsed = 0
        sleep_interval = 10
        last_status = ""
        
        while elapsed < max_wait:
            try:
                response = requests.get(
                    f"{self.hydralab_url}/api/test/task/{test_task_id}",
                    headers=headers,
                    timeout=10
                )
                response.raise_for_status()
                result = response.json()
                
                content = result.get('content', {})
                status = content.get('status', content.get('message', 'unknown'))
                
                # Check for completion
                if status == 'finished':
                    self.print_success("Test finished")
                    return content
                elif status == 'error':
                    self.print_error("Test failed with error")
                    return content
                elif status == 'canceled':
                    self.print_error("Test was canceled")
                    return None
                    
                # Show status update
                if status != last_status:
                    timestamp = datetime.now().strftime('%H:%M:%S')
                    print(f"[{timestamp}] Test status: {status}")
                    last_status = status
                    
                time.sleep(sleep_interval)
                elapsed += sleep_interval
                
            except requests.exceptions.RequestException as e:
                self.print_warning(f"Error checking status: {e}")
                time.sleep(sleep_interval)
                elapsed += sleep_interval
                
        self.print_error(f"Test timed out after {max_wait}s")
        return None
        
    def display_test_results(self, test_results: Dict[str, Any], test_task_id: str):
        """Display test results summary"""
        self.print_header("Test Results")
        
        total_tests = test_results.get('totalTestCount', 0)
        failed_tests = test_results.get('totalFailCount', 0)
        success_tests = total_tests - failed_tests
        device_count = test_results.get('testDevicesCount', 1)
        
        print(f"Device: {self.device_name} ({device_count} device(s))")
        print(f"Total tests: {total_tests}")
        print(f"Passed: {Colors.GREEN}{success_tests}{Colors.RESET}")
        print(f"Failed: {Colors.RED}{failed_tests}{Colors.RESET}")
        
        if total_tests > 0:
            success_rate = (success_tests / total_tests) * 100
            print(f"Success rate: {success_rate:.1f}%")
            
        print()
        print(f"Full report: {self.hydralab_url}/portal/index.html?redirectUrl=/info/task/{test_task_id}")
        print()
        
        # Check for artifacts
        device_results = test_results.get('deviceTestResults', [])
        if device_results:
            print("Test artifacts available:")
            for result in device_results[:1]:  # Show first device
                video = result.get('videoPath', 'N/A')
                gif = result.get('testGifPath', 'N/A')
                logs = result.get('logcatPath', 'N/A')
                print(f"  - Video: {video}")
                print(f"  - GIF: {gif}")
                print(f"  - Logs: {logs}")
                
        return failed_tests == 0 and test_results.get('status') != 'error'
        
    def run(self) -> int:
        """Main execution flow"""
        print(f"{Colors.BOLD}HydraLab iOS Test Runner{Colors.RESET}")
        print("=" * 70)
        
        # Step 1: Detect iOS device
        if not self.detect_ios_device():
            return 1
            
        # Step 2: Check auth token
        if not self.check_auth_token():
            return 1
            
        # Step 3: Check HydraLab center
        if not self.check_hydralab_center():
            return 1
            
        # Step 4: Verify test package
        test_info = self.verify_test_package()
        if not test_info:
            return 1
            
        # Step 5: Upload test package
        file_set_id = self.upload_test_package()
        if not file_set_id:
            return 1
            
        # Step 6: Trigger test run
        test_task_id = self.trigger_test_run(file_set_id, test_info)
        if not test_task_id:
            return 1
            
        # Step 7: Monitor execution
        test_results = self.monitor_test_execution(test_task_id)
        if not test_results:
            return 1
            
        # Step 8: Display results
        success = self.display_test_results(test_results, test_task_id)
        
        if success:
            self.print_success("All tests passed!")
            return 0
        else:
            self.print_error("Tests failed")
            return 1


def main():
    """Main entry point"""
    runner = HydraLabIOSTestRunner()
    sys.exit(runner.run())


if __name__ == '__main__':
    main()
