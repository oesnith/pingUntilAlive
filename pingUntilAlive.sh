#!/bin/bash

while getopts ":p:c:h:t:" opt; do
  case $opt in
	  p) # -p :: Port to test (will test via TCP)
      port=$OPTARG
      if [ -n "$port" ] && [ "$port" -eq "$port" ] 2>/dev/null; then
        echo -ne 
      else
        echo "Invalid argument for -p paramater. Must be a number" 
        exit 1
      fi
      ;;
    c) # -c :: Count of pings to send each test
      count=$OPTARG
      if [ -n "$count" ] && [ "$count" -eq "$count" ] 2>/dev/null; then
        echo -ne 
      else
        echo "Invalid argument for -c paramater. Must be a number" 
        exit 1
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
	exit 1
      fi
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Test that the host flag is populated, everything else will default to something.
if [ -z  "$host"  ]; then
	echo "Missing required -h flag. Please include the IP or FQDN."
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
	hostresolve=`dig +short $host`
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

#set -x
		# Spinner, attempt counter, and date.
		printf "\r(${spin:$i:1}) :: $j $attempts :: `date`"
		# If the port is set then do the TCP port check, if not do a ICMP ping.
		if [ -x $port ]; then
			# Ping with the variables set, capturing only the number of pings returned.
			pingreceived=`ping -q -W$timeout -c$count $pingaddress | grep received | awk '{print $4}'`
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
			echo "$livetext live @ `date`"
			exit
		#else
		#	echo "ping failed @ `date`"
		fi
#set +x
		((i=i+1))
		((j=j+1))
	done
fi
		
