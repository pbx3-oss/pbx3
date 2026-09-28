#!/bin/bash
# Voicemail externnotify — tenant-scoped VM BLF device-state.
# Args from Asterisk: context (tenant shortuid), mailbox/exten, new-msg count.
# Custom id must match GenClass hint: Custom:vm-{shortuid}-{ext}

VM_CONTEXT=$1
EXTEN=$2
VM_COUNT=$3

ASTCMD='/usr/sbin/asterisk -rx'
DEV="Custom:vm-${VM_CONTEXT}-${EXTEN}"

if [ "$VM_COUNT" = "0" ]; then
	$ASTCMD "devstate change ${DEV} NOT_INUSE"
else
	$ASTCMD "devstate change ${DEV} INUSE"
fi

exit 0
