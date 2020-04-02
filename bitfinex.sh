#!/bin/bash
# Bitfinex.sh  -- Websocket access to Bitfinex.com
# v0.2.21  dec/2019  by mountainner_br

## Some defaults
#if no stock is given, use this:
DEFMARKET=BTCUSD
#decimal plates (scale)
DECIMAL=2

#don't change these:
export LC_NUMERIC=en_US.UTF-8
COLOROPT="cat"

# BITFINIEX API DOCS
#https://docs.bitfinex.com/reference#ws-public-ticker

HELP="SYNOPSIS
	Bitfinex.sh [-c] [-sNUM|NUM] [SYMBOL]
	
	Bitfinex.sh [-hlv]


DESCRIPTION
	This script accesses the Bitfinex Exchange public API and fetches
	market data.

	Currently, only the trade live stream is implemented. If no market is 
	given, uses ${DEFMARKET}.
	

WARRANTY
	This programme is free software and is licensed under the GPLv3 or later.

	It needs the latest version of Bash, Curl or Wget, Gzip, JQ, Websocat, 
	Xargs and Lolcat to work properly.


OPTIONS
		-NUM 		Shortcut for \"-s\".

		-c 		Coloured live stream price (requires Lolcat).
		
		-h 		Show this help.

		-l 		List available markets.
		
		-s [NUM] 	Set number of decimal plates (scale); defaults=${DECIMAL}.

		-v 		Show script version."

#functions

#list markets
listf() {
	printf "Markets:\n"
	${YOURAPP} "https://api-pub.bitfinex.com/v2/tickers?symbols=ALL" |
		jq -r '.[][0]' | grep -v "^f[A-Z][A-Z][A-Z]*$" |
		tr -d 't' | sort | column -c80
	exit
}

# Bitfinex Websocket for Price Rolling -- Default opt
streamf() {
	#trap user INT signal
	trap 'printf "\nUser interrupted.\n" 1>&2; exit 0;' INT

	while true; do
		websocat -nt --ping-interval 5 "wss://api-pub.bitfinex.com/ws/2 " <<< "{ \"event\": \"subscribe\",  \"channel\": \"trades\",  \"symbol\": \"t${1^^}\" }" |
			jq --unbuffered -r '..|select(type == "array" and length == 4)|.[3]' |
			xargs -n1 printf "\n%.${DECIMAL}f" | ${COLOROPT}
		printf "\nPress Ctrl+C to exit.\n"
		N=$((++N))	
		printf "Reconnection #%s\n" "${N}" 1>&2
		sleep 4
	done
	exit
}

# Parse options
while getopts ":s:lhcv1234567890" opt; do
	case ${opt} in
		[0-9] ) #decimal setting, same as '-sNUM'                
			DECIMAL="${DECIMAL}${opt}"                               
			;;
			l ) # List Currency pairs
			LOPT=1
			;;
		s ) # Decimal plates (scale)
			DECIMAL="${OPTARG}"
			;;
		h ) # Show Help
			printf "%s\n" "${HELP}"
			exit 0
			;;
		c ) # Coloured price stream
			COLOROPT="lolcat -p 2000 -F 5"
			;;
		v ) # Version of Script
			grep -m1 '# v' "${0}"
			exit 0
			;;
		\? )
			printf "Invalid option: -%s\n" "${OPTARG}" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

# Test for must have packages
if ! command -v jq &>/dev/null; then
	printf "JQ is required.\n" 1>&2
	exit 1
fi
if command -v curl &>/dev/null; then
	YOURAPP='curl -sL --compressed'
elif command -v wget &>/dev/null; then
	YOURAPP="wget -qO-"
else
	printf "cURL or Wget is required.\n" 1>&2
	exit 1
fi

#request compressed response
if ! command -v gzip &>/dev/null; then
	printf 'warning: gzip may be required\n' 1>&2
fi

if [[ -z "${LOPT}" ]] && ! command -v websocat &>/dev/null; then
	printf "Websocat is required.\n" 1>&2
	exit 1
fi

#call opt functions
test -n "${LOPT}" && listf

## Check if there is any argument
## And set defaults
if [[ -z "${1}" ]]; then
	set -- "${DEFMARKET}"
fi

## Check for valid market pair
if ! grep -qi "^t${1}$" <<< "$(${YOURAPP} "https://api-pub.bitfinex.com/v2/tickers?symbols=ALL" | jq -r '.[][0]')"; then
	printf "Not a supported currency pair.\n" 1>&2
	printf "List available markets with \"-l\".\n" 1>&2
	exit 1
fi

#default option -- latest trade prices
streamf "${1}"

