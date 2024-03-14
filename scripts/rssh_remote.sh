#!/bin/bash
# Fill in <> with your applicable data. This will start a ssh session that you can then reverse ssh on.
ssh -b <yourdeviceipaddr> -R <portforrssh>:localhost:22 <yourusername>@<yourip> -p <youropenport>
exit