#!/usr/bin/env sh

# Capture Group 1) Extract the support-data string
# Capture Group 4) Extract the pod name (groups 2 and 3 are skipped here)
# Capture Group 5) Extract the timestamp with YYYYMMDDHHMM digits.  The last 2 digits + 'Z-zip' are left in capture group 6 (unused).
#
# pdo-1388 - Reorder the filename to make it more easily searchable:  <#5>-<#4>-<#1>.zip
# Transformation: support-data-ds-8.1.0.1-pingdirectory-0-20200903203030Z-zip => 202009032030-pingdirectory-0-support-data.zip
transform_csd_filename() {
  echo ${1} | sed -n "s/\(support-data\)-\(ds\)-\(.*\)-\(pingdirectory-[0-9]\)-\([0-9]\{12\}\)\([0-9]\{2\}Z-zip\)/\5-\4-\1.zip/p"
}
