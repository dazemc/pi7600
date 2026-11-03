#!/bin/bash
# Fill in <> with your applicable data. This will start a ssh session that you can then reverse ssh on.
sshpass -p <Password> ssh -fN -R <LocalHostPort>:localhost:22 <User>@<ConnectionAddress> -p <RouterAccessPort>
exit
