#!/usr/bin/bash

#open some tradingview windows at the right screen position

#screen resolution at 1366x768
#first chrome window must be sent to bg with '&'
#first sleep may need to be increased to open Chrome fully

google-chrome-stable --app=https://www.tradingview.com/chart/ISmYtO7U/ &
sleep 4  #may need to increse to open Chrome fully

nwa=`xdotool search --name trading | tail -1`
xdotool windowmove "$nwa" 0 0
sleep 1.3
xdotool windowsize "$nwa" 680 700 


google-chrome-stable --app=https://www.tradingview.com/chart/vSIVmcxS/
sleep 1.3
nwb=`xdotool search --name trading | tail -1`
xdotool windowmove "$nwb" 680 0
sleep 1.3
xdotool windowsize "$nwb" 680 700 

google-chrome-stable --app=https://www.tradingview.com/chart/h2YRqfnP/
sleep 1.3
nwc=`xdotool search --name trading | tail -1`
#xdotool windowmove "$nwc" 1367 0
xdotool windowmove "$nwc" 0 0
sleep 1.3
xdotool windowsize "$nwc" 680 700

google-chrome-stable --app=https://www.tradingview.com/chart/nNx9sErC/
sleep 1.3
nwd=`xdotool search --name trading | tail -1`
#xdotool windowmove "$nwd" 2033 0
xdotool windowmove "$nwd" 681 0
sleep 1.3
xdotool windowsize "$nwd" 680 700 

echo "This script took $SECONDS seconds to execute" 1>&2

disown

