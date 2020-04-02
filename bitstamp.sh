#!/bin/bash
#
# Bitstamp.sh  -- Websocket access to Bitstamp.com
# v0.3.4.1  14/nov/2019  by mountainner_br

## Some defaults
export LC_NUMERIC=en_US.UTF-8
COLOROPT="cat"
DECIMAL=2

HELP="SYNOPSIS
	bitstamp.sh [-c] [-fNUM] [-i|-s] [MARKET]

	bitstamp.sh [-h|-l|-v]


DESCRIPTION:
	
	This script accesses the Bitstamp Exchange public API and fetches
	market data. Currently, only the live trade stream is implemented.

	Options \"-s\" and \"-i\" shows the same data as in:
		<https://www.bitstamp.net/s/webapp/examples/live_trades_v2.html>


WARRANTY
	This programme needs latest version of Bash, JQ, Websocat, Xargs and 
	Lolcat.	This is free software and is licensed under the GPLv3 or later.

	Give me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


OPTIONS
		-f [NUM] 	Set number of decimal plates; defaults=2.

		-i [MARKET] 	Live trade stream with more info.

		-h 	 	Show this help.

		-l 	 	List available markets.
		
		-s [MARKET] 	Live trade stream (default opt).
		
		-c		Coloured prices; only for use with option \"-s\".
		
		-v 		Show this programme version."

## Trade stream - Bitstamp Websocket for Price Rolling
streamf() {
while true; do
	websocat -nt --ping-interval 20 "wss://ws.bitstamp.net" <<< "{ \"event\": \"bts:subscribe\",\"data\": { \"channel\": \"live_trades_${1,,}\" } }" | jq --unbuffered -r '.data.price // empty' | xargs -n1 printf "\n%.${DECIMAL}f" | ${COLOROPT}
	#2>/dev/null
	printf "\nPress Ctrl+C twice to exit.\n"
	N=$((N+1))	
	printf "Recconection #${N}\n"
	sleep 4
done
exit
}

# Trade stream more info
istreamf() {
while true; do
	websocat -nt --ping-interval 20 "wss://ws.bitstamp.net" <<< "{ \"event\": \"bts:subscribe\",\"data\": { \"channel\": \"live_trades_${1,,}\" } }" | jq --unbuffered -r '.data|"P: \(.price // empty) \tQ: \(.amount // empty) \tPQ: \((if .price == null then 1 else .price end)*(if .amount == null then 1 else .amount end)|round)    \t\(.timestamp // empty|tonumber|strflocaltime("%Y-%m-%dT%H:%M:%S%Z"))"' | ${COLOROPT}
	#2>/dev/null
	printf "\nPress Ctrl+C twice to exit.\n"
	N=$((N+1))	
	printf "Recconection #${N}\n"
	sleep 4
done
exit
}

CPAIRS=(bchbtc bcheur bchusd btceur btcusd ethbtc etheur ethusd eurusd ltcbtc ltceur ltcusd xrpbtc xrpeur xrpusd)
# From: https://www.bitstamp.net/websocket/v2/
# Parse options
# If the very first character of the option string is a colon (:)
# then getopts will not report errors and instead will provide a means of
# handling the errors yourself.
while getopts ":cf:lhsiv" opt; do
  case ${opt} in
  	l ) # List Currency pairs
		printf "Markets:\n"
		printf "%s\n" "${CPAIRS[*]^^}"
		printf "Also check <https://www.bitstamp.net/websocket/v2/>.\n"
		exit
		;;
	f ) # Decimal plates
		DECIMAL="${OPTARG}"
		;;
	h ) # Show Help
		printf "%s\n" "${HELP}"
		exit 0
		;;
	i ) # Price stream with more info
		ISTREAMOPT=1
		;;
	s ) # B&W price stream
		STREAMOPT=1
		;;
	c ) # Coloured price stream
		COLOROPT="lolcat -p 2000 -F 5"
		;;
	v ) # Version of Script
		head "${0}" | grep -e '# v'
		exit
		;;
	\? )
		echo "Invalid Option: -$OPTARG" 1>&2
		exit 1
		;;
  esac
done
shift $((OPTIND -1))


## Check if there is any argument
## And set defaults
if ! [[ "${1}" =~ [a-zA-Z]+ ]]; then
	set -- btcusd
fi

## Check for valid market pair
if ! grep -qi "${1}" <<< "${CPAIRS[@]}"; then
	printf "Usupported market/currency pair.\n" 1>&2
	printf "Run \"-l\" to list available markets.\n" 1>&2
	exit 1
fi

# Run Functions
# Trade price stream
test -n "${STREAMOPT}" && streamf ${@}
# Trade price stream with additional information
test -n "${ISTREAMOPT}" && istreamf ${@}

#If no option set, run default opt
streamf ${@}


