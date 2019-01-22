[appurl]: https://rclone.org/
[healthchecks]: https://healthchecks.io/

FORK FROM tynor88/docker-rclone

**Parameters**

* `-v /config` The path where the .rclone.conf file is
* `-v /data` The path to the data which should be backed up by Rclone
* `-v RCLONE_JOBNAME` Will using as the top level folder in order to move edit/delete files to --backup-dir.
* `-v RCLONE_METHOD` Else then copy/sync should using RCLONE_CMD instead.
* `-e RCLONE_CMD` A custom rclone command which will override the default value of: rclone $RCLONE_METHOD $RCLONE_SOURCE $RCLONE_DEST/$RCLONE_JOBNAME
* `-e RCLONE_SOURCE` The srouce folder, should not be empty.
* `-e RCLONE_DEST` The destination that the data should be backued up to (must be the same name as specified in .rclone.conf)
* `-e RCLONE_OPTIONS` Additional options. See rclone docs for additional options.
* `-e RCLONE_CHECKING_URL` Health check service. like healthchecks.io
* `-e RCLONE_MOVE_OLD_FILES_TO` dated_directory, will move old files to a dated folder. dated_files, will move old files to a folder named by date and append date and time to file name. If not specified, old file will be overwritted or deleted.
* `-e RCLONE_CONFIG_PASS` If the rclone.conf is encrypted, specify the password here
* `-e CRON_SCHEDULE` A custom cron schedule which will override the default value of: 0 * * * * (hourly)


## Info

* Shell access whilst the container is running: `docker exec -it Rclone /bin/ash`
* Upgrade to the latest version: `docker restart Rclone`
* To monitor the logs of the container in realtime: `docker logs -f Rclone`

