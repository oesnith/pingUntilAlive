# pingUntilAlive.sh
## Description
Run a continuous ping check or port check until it's alive, then stop and print the time it became alive.

## Prerequisites:

* curl
* dig
* ping


## Flags:
```
-h :: host (Required - FQDN or IP)
-c :: count (number of pings to send)
-t :: timeout (number of seconds to wait for ping return)
-p :: port (for TCP port check)
-n :: notification (Enable Pushover Notification)
      Must include USERKEY and APIKEY from your Pushover account delimited by '::'
      -n will override -N
-N :: notification (Enable Pushover Notification) from config file.
      Uses the Pushover API information from the config file.
      Defined using -f, or using pingUntilAlive.conf located in script directory
-f :: config file - Full path.
      Default: pingUntilAlive.conf located in the directory with this script
      Tab Delimited file.  See pingUntilAlive.conf.sample file.
```
