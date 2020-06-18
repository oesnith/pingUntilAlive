# pingUntilAlive
Run a continuous ping check or port check until it's alive, then stop and print the time it became alive.

Flags:

-h :: host (Required - FQDN or IP)

-c :: count (number of pings to send)

-t :: timeout (number of seconds to wait for ping return)

-p :: port (for TCP port check)

Todo:

Add a --help and clean up proper Usage information when flags are missing or used wrong.
