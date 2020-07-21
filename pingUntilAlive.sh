#!/bin/bash

#######################################################################################
# pingUntilAlive.sh                                                                   #
# Run a continuous ping check or port check until it's alive,                         #
# then stop and print the time it became alive.                                       #
#                                                                                     #
# Flags:                                                                              #
# -h :: host (Required - FQDN or IP)                                                  #
# -c :: count (number of pings to send)                                               #
# -t :: timeout (number of seconds to wait for ping return)                           #
# -p :: port (for TCP port check)                                                     #
# -n :: notification (Enable Pushover Notification)                                   #
#       Must include USERKEY and APIKEY from your Pushover account delimited by '::'  #
#       -n will override -N                                                           #
# -N :: notification (Enable Pushover Notification) from config file.                 #
#       Uses the Pushover API information from the config file.                       #
#       Defined using -f, or using pingUntilAlive.conf located in script directory    #
# -f :: config file - Full path.                                                      #
#       Default: pingUntilAlive.conf located in the directory with this script        #
#                                                                                     #
#######################################################################################

programname=$0
usage () {
   echo
   echo "Usage: $programname -h FQDN [-c count] [-t timeout] [-p port] [-n USERKEY|APIKEY] [-N] [-f filename]"
   echo "  -h	host (FQDN or IP)"
   echo "  -c	count (number of pings to send)"
   echo "  -t	timeout (number of second to wait for ping return)"
   echo "  -p	port (for TCP port check)"
   echo "  -n	notification (Enable Pushover Notification)"
   echo "          Must include USERKEY and APIKEY from your Pushover account"
   echo "          delimited by '::'" 
   echo "          -n will override -N"
   echo "  -N   notification (Enable Pushover Notification) from config file."
   echo "          Uses the Pushover API information from the config file."
   echo "          Defined using -f, or using pingUntilAlive.conf located in"
   echo "          script directory"
   echo "  -f   config file - Full path.  Default: pingUntilAlive.conf located"
   echo "          in the directory with this script"
   exit 1
}

sendPushover () {
   local title="${1:cli-app}"
   local message="$2"
   [[ "$message" != "" ]] && $curlcmd -s --form-string "token=${PO_ApiKey}" --form-string "user=${PO_UserKey}" --form-string "title=$title" --form-string "message=$message" https://api.pushover.net/1/messages.json
}

# Check for prereqs
prereq_failed="FALSE"
prereq_failed_text=""
curlcmd=`which curl`
digcmd=`which dig`
pingcmd=`which ping`
if [ -z "$curlcmd" ] ; then
   prereq_failed="TRUE"
   prereq_failed_text=$'curl\n'
fi   
if [ -z "$digcmd" ] ; then
   prereq_failed="TRUE"
   prereq_failed_text_tmp=$'dig\n'
   prereq_failed_text="$prereq_failed_text$prereq_failed_text_tmp"
fi   
if [ -z "$pingcmd" ] ; then
   prereq_failed="TRUE"
   prereq_failed_text_tmp=$'ping\n'
   prereq_failed_text="$prereq_failed_text$prereq_failed_text_tmp"
fi   
if [[ "$prereq_failed" == "TRUE" ]] ; then
   echo "***WARNING! SCRIPT EXITED***"
   echo "Your system is missing the following required package(s):"
   echo "$prereq_failed_text"
   echo "Please install before continuing."
   usage
fi
#Runtime variables
   configfile="pingUntilAlive.conf"

while getopts ":p:c:h:t:f:n:N" opt; do
   case $opt in
      p) # -p :: Port to test (will test via TCP)
         port=$OPTARG
         if [ -n "$port" ] && [ "$port" -eq "$port" ] 2>/dev/null; then
            echo -ne 
         else
            echo "Invalid argument for -p paramater. Must be a number" 
            usage 
         fi
         ;;
      c) # -c :: Count of pings to send each test
         count=$OPTARG
         if [ -n "$count" ] && [ "$count" -eq "$count" ] 2>/dev/null; then
            echo -ne 
         else
            echo "Invalid argument for -c paramater. Must be a number" 
            usage 
         fi
         ;;
      h) # -h :: Host FQDN or IP address to test
         host=$OPTARG
         ;;
      t) # -t :: Timeout for ping requests in seconds
         timeout=$OPTARG
         if [ -n "$timeout" ] && [ "$timeout" -eq "$timeout" ] 2>/dev/null; then
            echo -ne 
         else
            echo "Invalid argument for -t paramater. Must be a number" 
	    usage	
         fi
         ;;
      f) # -f Config File
         configfile=$OPTARG 
         if [ ! -f "$configfile" ] ; then
            echo "Config file not found: $configfile"
            usage
         fi
         ;;
      n) # -n Pushover notification - USERKEY|APIKEY
         PO_info=$OPTARG
         if [[ "$PO_info" != *"::"* ]]; then
            echo "Invalid argument for -n parameter. Must include your Pushover User Key and Pushover API Key delimited by '::'"
            usage
         fi
         PO_UserKey=`echo $PO_info | awk -F "::" '{print $1}'`
         PO_ApiKey=`echo $PO_info | awk -F "::" '{print $2}'`
         ;;
      N) # -N Pushover notification - Get USERKEY and APIKEY from config file.  Default: pingUntilAlive.conf located in the same directory
         #Need to process this AFTER the rest of the arguments are processed so the config file gets set properly
         followup_N="TRUE"
         ;;
      \?)
         echo "Invalid option: -$OPTARG" >&2
         usage
         ;;
      :)
         echo "Option -$OPTARG requires an argument." >&2
         usage
         ;;
   esac
done

#Do the followup processing of the -N flag.
if [ "$followup_N" == "TRUE" ] ; then
   if [ "$PO_UserKey" == "" ] || [ "$PO_ApiKey" == "" ] ; then
      PO_UserKey=`grep PUSHOVER-USERKEY $configfile | awk '{print $2}'`
      PO_ApiKey=`grep PUSHOVER-APIKEY $configfile | awk '{print $2}'`
      PO_info="Filler"
   fi
   if [ "$PO_UserKey" == "" ] || [ "$PO_ApiKey" == "" ] ; then
      echo "No PUSHOVER-USERKEY or PUSHOVER-API key values found in $configfile."
      echo "Please add them to the file with a tab delimiter."
      usage
   fi

fi
# Test that the host flag is populated, everything else will default to something.
if [ -z  "$host"  ]; then
   echo "Missing required -h flag. Please include the IP or FQDN."
   usage
   exit
else # If the host flag is populated set defaults for timeout and count if none set.
   if [ -z $timeout ] ; then
      timeout=2
   fi
   if [ -z $count ] ; then
      count=1
   fi

   # Setting up some variables
   pingaddress=$host
   hostresolve=`$digcmd +short $host | awk '{print ; exit }'`
   if [ -z $hostresolve ]; then
      printip=""
   else
      printip=" ($hostresolve)"
   fi

   # Setting up the spinner to show the script is still going.
   spin='-\|/'

   # Setting up some variables for the loop.
   pinglive=0
   i=0
   j=1

   # Starting to get going with the pings.
   if [ -x $port ]; then
      testtext="Pinging"
   else
      testtext="Testing Port $port on"
   fi
   
   echo "$testtext $pingaddress$printip until live . . ."
	
   # Keep going until the ping is successful.
   while [ $pinglive -eq 0 ]
   do
      i=$(( (i+1) %4 )) # Used to keep the spinner changing.

      # This is just to make the grammer proper...
      if [ $j -eq 1 ] ; then
         attempts="Attempt "
      else
         attempts="Attempts"
      fi

      # Spinner, attempt counter, and date.
      printf "\r(${spin:$i:1}) :: $j $attempts :: `date`"
      # If the port is set then do the TCP port check, if not do a ICMP ping.
      if [ -x $port ]; then
         # Ping with the variables set, capturing only the number of pings returned.
         pingreceived=`$pingcmd -q -W$timeout -c$count $pingaddress | grep received | awk '{print $4}'`
      else
         # Using /dev/tcp to test the port requested. One-liner if statement
         if echo "blarg" 2>/dev/null > /dev/tcp/$pingaddress/$port; then tcpreturn=1; else tcpreturn=0; fi

      # If it is open set $pingreceived to 1, if not, sleep for the set timeout
         if [[ "$tcpreturn" -gt 0 ]]; then
            pingreceived="1"
         else
            sleep $timeout
         fi
      fi
      # If the test was successful then print the date and kick out of the loop.
      if [[ "$pingreceived" -gt 0 ]]; then
         pinglive=1
         printf "\r(*) :: $j $attempts :: `date`"
         echo
         if [ -x $port ]; then
            livetext="Ping"
         else
            livetext="Port $port"
         fi
	 printtext="$livetext live @ `date`"
         echo "$printtext"
	 if [ ! -x $PO_info ]; then
            echo -n "Sending Pushover notification : "
	    sendPushover "pingUntilAlive - $host Alive" "$printtext
$j $attempts"
	    echo
         fi
         exit
         #else
            #echo "ping failed @ `date`"
      fi
      ((i=i+1))
      ((j=j+1))
   done
fi
		
