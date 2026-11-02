#!/bin/bash

set -euo pipefail

# The single source of truth for the recovery.fstab file is the sm7250-common repo.
# This script fetches it and ensures our copy is up to date.

REMOTE_URL="https://raw.githubusercontent.com/TangYani2024/android_device_motorola_sm7250-common-AERA/aera-16.0/recovery.fstab"
LOCAL_FILE="recovery/root/system/etc/recovery.fstab"

TEMP_FILE=$(mktemp)
# Fetch the remote fstab
curl -sL "$REMOTE_URL" > "$TEMP_FILE"

# Prepend the required header to a new temporary file
TEMP_FILE_WITH_HEADER=$(mktemp)
trap 'rm -f "$TEMP_FILE" "$TEMP_FILE_WITH_HEADER"' EXIT

echo "# Copy of sm7250-common recovery.fstab — edit there, then run tools/sync_fstab.sh" > "$TEMP_FILE_WITH_HEADER"
cat "$TEMP_FILE" >> "$TEMP_FILE_WITH_HEADER"

if ! diff -u "$LOCAL_FILE" "$TEMP_FILE_WITH_HEADER"; then
    echo "Error: The local recovery.fstab differs from the upstream source of truth."
    echo "Please update the sm7250-common repo or run this script to update the local copy."
    exit 1
fi

echo "The local recovery.fstab is up to date with the sm7250-common repo."
exit 0
