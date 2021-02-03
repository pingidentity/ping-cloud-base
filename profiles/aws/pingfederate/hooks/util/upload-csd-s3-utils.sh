#!/usr/bin/env sh

# Capture Group 1) Extract the support-data string
# Capture Group 3) Extract the pod name (group 2 is skipped here)
# Capture Group 4) Extract the timestamp with YYYYMMDDHHMM digits.  The last 2 digits are left in capture group 5 (unused).
#
# pdo-1388 - Reorder the filename to make it more easily searchable:  <#4>-<#3>-<#1>.zip
# Transformation: support-data-ping-pingfederate-1-2021012520153000.zip => 20210125201530-pingfederate-1-support-data.zip
transform_csd_filename() {
    echo ${1} | sed -n "s/\(support-data\)-\(ping\)-\(.*\)-\([0-9]\{12\}\)\([0-9]\{2\}\)/\4-\3-\1.zip/p"
}