// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

package com.microsoft.hydralab.common.util;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

public class ZipBombChecker {
    // Increased limit to 10GB to support large game/app builds
    private static final long MAX_UNCOMPRESSED_SIZE = 10L * 1024 * 1024 * 1024;
    private static final int MAX_ENTRIES = 100000;
    private static final int MAX_NESTING_DEPTH = 5;

    public static boolean isZipBomb(File file) {
        return isZipBomb(file, 0);
    }

    private static boolean isZipBomb(File file, int depth) {
        if (depth > MAX_NESTING_DEPTH) {
            return true;
        }

        long totalUncompressedSize = 0;
        int entryCount = 0;

        try (ZipInputStream zis = new ZipInputStream(new FileInputStream(file))) {
            ZipEntry entry;
            byte[] buffer = new byte[8192];

            while ((entry = zis.getNextEntry()) != null) {
                entryCount++;
                if (entryCount > MAX_ENTRIES) {
                    return true;
                }

                if (!entry.isDirectory()) {
                    // Check if the entry is a nested zip file
                    boolean isNestedZip = entry.getName().toLowerCase().endsWith(".zip");
                    
                    File tempZip = null;
                    FileOutputStream fos = null;
                    
                    if (isNestedZip) {
                        tempZip = File.createTempFile("nested", ".zip");
                        fos = new FileOutputStream(tempZip);
                    }

                    int len;
                    while ((len = zis.read(buffer)) > 0) {
                        totalUncompressedSize += len;
                        if (totalUncompressedSize > MAX_UNCOMPRESSED_SIZE) {
                            if (fos != null) {
                                fos.close();
                            }
                            if (tempZip != null) {
                                tempZip.delete();
                            }
                            return true;
                        }
                        
                        // Only write to disk if it's a nested zip we need to check recursively
                        if (fos != null) {
                            fos.write(buffer, 0, len);
                        }
                    }
                    
                    if (fos != null) {
                        fos.close();
                        boolean nestedBomb = isZipBomb(tempZip, depth + 1);
                        tempZip.delete();
                        if (nestedBomb) {
                            return true;
                        }
                    }
                }
                zis.closeEntry();
            }
        } catch (Exception e) {
            // If there's an error reading the zip (e.g. malformed), treat as potential threat
            return true;
        }
        return false;
    }
}
