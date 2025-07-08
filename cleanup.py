#!/usr/bin/env python3
"""
Cleanup script for KPCL OTP Project
Removes temporary files and cleans up session data
"""

import os
import shutil
import glob

def clean_sessions():
    """Clean up session files"""
    sessions_dir = 'sessions'
    if os.path.exists(sessions_dir):
        session_files = glob.glob(os.path.join(sessions_dir, '*'))
        if session_files:
            print(f"🧹 Cleaning {len(session_files)} session file(s)...")
            for file_path in session_files:
                try:
                    if os.path.isfile(file_path):
                        os.remove(file_path)
                        print(f"  ✅ Removed {file_path}")
                    elif os.path.isdir(file_path):
                        shutil.rmtree(file_path)
                        print(f"  ✅ Removed directory {file_path}")
                except Exception as e:
                    print(f"  ❌ Error removing {file_path}: {e}")
        else:
            print("✅ No session files to clean")
    else:
        print("⚠️  Sessions directory not found")

def clean_cache():
    """Clean Python cache files"""
    cache_patterns = [
        '**/__pycache__',
        '**/*.pyc',
        '**/*.pyo'
    ]
    
    files_removed = 0
    
    for pattern in cache_patterns:
        for file_path in glob.glob(pattern, recursive=True):
            try:
                if os.path.isfile(file_path):
                    os.remove(file_path)
                    files_removed += 1
                elif os.path.isdir(file_path):
                    shutil.rmtree(file_path)
                    files_removed += 1
            except Exception as e:
                print(f"  ❌ Error removing {file_path}: {e}")
    
    if files_removed > 0:
        print(f"🧹 Cleaned {files_removed} cache file(s)")
    else:
        print("✅ No cache files to clean")

def clean_logs():
    """Clean any log files that might exist"""
    log_patterns = [
        '*.log',
        'logs/*.log'
    ]
    
    files_removed = 0
    
    for pattern in log_patterns:
        for file_path in glob.glob(pattern):
            try:
                os.remove(file_path)
                files_removed += 1
                print(f"  ✅ Removed log file {file_path}")
            except Exception as e:
                print(f"  ❌ Error removing {file_path}: {e}")
    
    if files_removed > 0:
        print(f"🧹 Cleaned {files_removed} log file(s)")
    else:
        print("✅ No log files to clean")

def main():
    """Main cleanup function"""
    print("🧹 KPCL OTP Project Cleanup\n")
    
    clean_sessions()
    clean_cache()
    clean_logs()
    
    print("\n✅ Cleanup completed!")

if __name__ == "__main__":
    main()
