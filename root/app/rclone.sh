#!/usr/bin/with-contenv sh

########## variabled ##########
DATE_NOW=$(date +%F)
TIME_NOW=$(date +%H_%M_%S)
DATE_TIME="$DATE_NOW"_"$TIME_NOW"
#RUN_ID=$(< /dev/urandom tr -dc 0-9 | head -c${1:-8})
RUN_ID=$(tr -dc '0-9' < /dev/urandom | head -c5)

LOGS=/config/rclone-$RUN_ID-$DATE_TIME.log
SLOGS=/config/rclone-log-$DATE_NOW.log

########## static files ##########

#LOGS=/config/rclone-$DATE_TIME.log
#SLOGS=/config/rclone-log-$DATE_NOW.log

if [ "$RCLONE_JOBNAME" ];
then
  LOGS=/config/rclone-$RUN_ID-$RCLONE_JOBNAME-$DATE_TIME.log
  SLOGS=/config/rclone-log-$RCLONE_JOBNAME-$DATE_NOW.log
fi

########## functions ##########
do_log()
{
   msg="$1"
   echo "$msg" >> "$LOGS"
}

do_echo()
{
  urgency="$1"
  msg="$2"
  message="$RUN_ID | $(date +%F_%T) ${urgency}: $msg"
  
  echo "$message"
  do_log "$message"
}

do_echo_settings()
{
  do_echo "SETTING" "RCLONE_JOBNAME           : $RCLONE_JOBNAME"
  do_echo "SETTING" "RCLONE_METHOD            : $RCLONE_METHOD"
  do_echo "SETTING" "RCLONE_SOURCE            : $RCLONE_SOURCE"
  do_echo "SETTING" "RCLONE_DEST              : $RCLONE_DEST"
  do_echo "SETTING" "RCLONE_OPTIONS           : $RCLONE_OPTIONS"
  do_echo "SETTING" "RCLONE_LOGS              : $RCLONE_LOGS"
  do_echo "SETTING" "RCLONE_CHECKING_URL      : $RCLONE_CHECKING_URL"

  if [ "$RCLONE_BACKUP_DIR" ];
  then
    do_echo "SETTING" "RCLONE_MOVE_OLD_FILES_TO : $RCLONE_MOVE_OLD_FILES_TO"
    do_echo "SETTING" "RCLONE_BACKUP_DIR        : $RCLONE_BACKUP_DIR"
  fi
  
  do_echo "SETTING" "CMD                      : $CMD"

}

do_ping()
{
  if [ "$HC" -eq 1 ];
  then
    url="$RCLONE_CHECKING_URL/$1"

    if [ -z "$1" ];
    then 
      url="$RCLONE_CHECKING_URL"
    fi

    header='--header="User-Agent: ID=$RUN_ID MSG=$2 LOGS=$LOGS JOB=$RCLONE_JOBNAME"'
    cmd="wget $header $url -q -O /dev/null"
    eval "$cmd"
  fi
}
########## parameters ##########


#
#--- Setting monitoring url
#
if [ -z "$RCLONE_CHECKING_URL" ];
then
  do_echo "INFO" "A health check has not been set. Not using health check services"

else
  do_echo "INFO" "RCLONE_CHECKING_URL:$RCLONE_CHECKING_URL"
  HC=1
fi

#
#-- Start healthcheck
#
do_ping "start"

#
#-- Setting default job name
# This will be using as the top level folder name
# The first time rclone copy/sync will be in this folder
# It is the current snapshot of the source
if [ -z "$RCLONE_JOBNAME" ];
then
  RCLONE_JOBNAME="current"
  do_echo "INFO" "RCLONE_JOBNAME has not been set, default value [current] has been applied."
fi

#
#--- Setting default rclone method
#
if [ -z "$RCLONE_METHOD" ];
then
  RCLONE_METHOD="sync"
  do_echo "INFO" "RCLONE_METHOD has not been set, default value [sync] has been applied."
fi
#
#--- Setting default source path
#
if [ -z "$RCLONE_SOURCE" ];
then
  RCLONE_SOURCE="/data"
  do_echo "INFO" "RCLONE_SOURCE has not been set, default value [/data] has been applied."
fi

#
#--- Checking if source if empty folder
#
if [ "$RCLONE_SOURCE" = "/data" ];
then
  if ! ( ls -1A $RCLONE_SOURCE | grep -q . );
  then
    do_echo "ERROR" "$RCLONE_SOURCE folder is empty."
    do_ping "fail" "source folder empty"
    exit 1
  fi
fi

#
#--- End runtime if there is no destination path
#
if [ -z "$RCLONE_DEST" ];
then
  do_echo "ERROR" "RCLONE_DEST environment variable was not passed."
  do_ping "fail" "no dest folder"
  exit 1
fi

#
#--- Setting default move_old_files_to path
# default will move old files to "dated_directory"
# should one of "dated_directory" "dated_files"
# "dated_directory" move old files to a dated directory like incremental backup
# "dated_files" move old files to "old_files" directory and append move date to file name like incremental backup
# "overwritten_deleted" old files are overwirtten or deleted one way backup
#
if [ -z "$RCLONE_MOVE_OLD_FILES_TO" ];
then
  RCLONE_MOVE_OLD_FILES_TO="dated_directory"
  do_echo "INFO" "RCLONE_MOVE_OLD_FILES_TO has not been set, default value [dated_directory] has been applied."
fi

#
#--- Setting backup-dir
#
if [ "$RCLONE_MOVE_OLD_FILES_TO" = "dated_directory" ];
then
  RCLONE_BACKUP_DIR="--backup-dir=$RCLONE_DEST/$RCLONE_JOBNAME-archive/$DATE_NOW/$TIME_NOW"

elif [ "$RCLONE_MOVE_OLD_FILES_TO" = "dated_files" ];
then
  RCLONE_BACKUP_DIR="--backup-dir=$RCLONE_DEST/$RCLONE_JOBNAME-archive/$DATE_NOW --suffix=_$TIME_NOW"

else [ "$RCLONE_MOVE_OLD_FILES_TO" = "overwritten_deleted" ];
  RCLONE_BACKUP_DIR=""  
fi

if [ "$RCLONE_BACKUP_DIR" ];
then
  do_echo "INFO" "RCLONE_MOVE_OLD_FILE_TO:$RCLONE_MOVE_OLD_FILES_TO"
  do_echo "INFO" "RCLONE_BACKUP_DIR:$RCLONE_BACKUP_DIR"
fi

#
#--- Setting other options
#
if [ -z "$RCLONE_OPTIONS" ];
then
  RCLONE_OPTIONS=""
  do_echo "INFO" "RCLONE_OPTIONS:$RCLONE_OPTIONS"

else
  do_echo "INFO" "RCLONE_OPTIONS:$RCLONE_OPTIONS"
fi

#
#--- Setting Log
#
RCLONE_LOGS="-vvv --log-file=$LOGS"

#
#--- Start rclone job
#
(
  flock -n 300 ||
  { 
    do_echo "ERROR" "Another cron still runing." 
    do_ping "fail" "concurrent job"
    exit 1
  }

# default command
  CMD="rclone $RCLONE_METHOD $RCLONE_SOURCE $RCLONE_DEST/$RCLONE_JOBNAME $RCLONE_OPTIONS $RCLONE_BACKUP_DIR $RCLONE_LOGS"

# from env
  if [ "$RCLONE_CMD" ];
  then
    CMD="$RCLONE_CMD"
  fi

  do_echo_settings
  
  eval "$CMD"

# checking if exit code eq 0
  RCLONE_EXIT_CODE=$?

  if [ "$RCLONE_EXIT_CODE" -eq 0 ];
  then
    do_echo "INFO" "The transfer has completed. For more info please referr to $LOGS"
    EXPORT_LOG="cat $LOGS >> $SLOGS && rm $LOGS"
    eval "$EXPORT_LOG"
    do_ping
    exit 0

  else
    do_echo "ERROR" "The transfer has not completed. rclone exit with error. Please check logs at $LOGS"
    do_ping "fail" "rclone exit with error"
    exit 1
  fi

) 300>/var/lock/rclone.lock


