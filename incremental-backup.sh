#!/bin/bash
# ----------------------------------------------------------------------
# Szilveszter's handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots of /whatever 
# ----------------------------------------------------------------------

unset PATH	# suggestion from H. Milz: avoid accidental use of $PATH

# ------------- system commands used by this script --------------------
ID=/usr/bin/id;
ECHO=/usr/bin/echo;

MOUNT=/usr/bin/mount;
UMOUNT=/usr/bin/umount;
RM=/usr/bin/rm;
MV=/usr/bin/mv;
CP=/usr/bin/cp;
TOUCH=/usr/bin/touch;
MKDIR=/usr/bin/mkdir;
DATE=/usr/bin/date;

RSYNC=/usr/bin/rsync;


# ------------- file locations -----------------------------------------

MOUNT_DEVICE=/dev/sdb1;
SNAPSHOT_RW=/backup;
BACKUPDESTINATION=$SNAPSHOT_RW/snapshots;
CURRENT_SNAPSHOT=$BACKUPDESTINATION/backup.latest;
ONE_DAY_OLD_SNAPSHOT=$BACKUPDESTINATION/backup.one_day_old;
TWO_DAYS_OLD_SNAPSHOT=$BACKUPDESTINATION/backup.two_days_old;
BACKUPTARGET=/;
DONT_BACKUP_BEFORE_HOUR=17;

# ------------- the script itself --------------------------------------

# make sure we're running as root
if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

# check if there is already a backup made today 
currentHour=$($DATE "+%H")
currentDate=$($DATE "+%m-%d-%Y")
latestBackupChangeDate=$($DATE -r "$CURRENT_SNAPSHOT" "+%m-%d-%Y") 
if [[ $currentHour < $DONT_BACKUP_BEFORE_HOUR || $currentDate == $latestBackupChangeDate ]]
then
    echo "There is already a backup made today. Exiting..."
    exit 0
else 
    echo "Creating the daily incremental backup..."
fi;


# attempt to remount the RW mount point as RW; else abort
$MOUNT -o remount,rw $MOUNT_DEVICE $SNAPSHOT_RW ;
if (( $? )); then
{
	$ECHO "snapshot: could not remount $SNAPSHOT_RW readwrite";
	exit;
}
fi;

# rotating snapshots of / (fixme: this should be more general)

# step 0: check if SNAPSHOT_RW directory exists
[ -d "$BACKUPDESTINATION" ] || $MKDIR -p $BACKUPDESTINATION ; 

# step 1: delete the oldest snapshot, if it exists:
if [ -d "$TWO_DAYS_OLD_SNAPSHOT" ] ; then			\
    $RM -rf $TWO_DAYS_OLD_SNAPSHOT ;				\
fi ;

# step 2: shift the middle snapshots(s) back by one, if they exist
if [ -d "$ONE_DAY_OLD_SNAPSHOT" ] ; then			\
    $MV $ONE_DAY_OLD_SNAPSHOT $TWO_DAYS_OLD_SNAPSHOT ;	\
fi;

# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
if [ -d "$CURRENT_SNAPSHOT" ] ; then			\
    $CP -al $CURRENT_SNAPSHOT $ONE_DAY_OLD_SNAPSHOT ;	\
fi;

# step 4: rsync from the system into the latest snapshot (notice that
# rsync behaves like cp --remove-destination by default, so the destination
# is unlinked first.  If it were not so, this would copy over the other
# snapshot(s) too!
$RSYNC								\
	-va --delete --delete-excluded  \
    --exclude=/proc/* --exclude=/run/* --exclude=/sys/* \
    --exclude=/dev/* --exclude=/tmp/* --exclude=/backup/* \
	$BACKUPTARGET $CURRENT_SNAPSHOT ;

# step 5: update the mtime of backup.latest to reflect the snapshot time
$TOUCH $CURRENT_SNAPSHOT ;

# and thats it for /.

# we are after systemd unmount filesystems, 
# it is better if we unmount the backup before the actual shutdown 
$UMOUNT $MOUNT_DEVICE ;
