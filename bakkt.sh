#!/bin/bash
#
# v0.1.16 apr/2020  by castaway

HELP="WARRANTY
	Licensed under the GNU Public License v3 or better and is distributed 
	without support or bug corrections.

	If you found this script useful, consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


SINOPSIS
	bakkt.sh 

	bakkt.sh [-hv]

	Bakkt price ticker and contract volume from <https://www.bakkt.com/> 
	at the terminal. The default option lists ICE Bakkt Bitcoin (USD) Month-
	ly Futures.

	Option '-t' for time series of contract price. Change range with arg-
	uments 1-3. The list is tab-separated.

	Market data delayed a minimum of 15 minutes. 

	Required software: Bash, JQ, gzip and cURL or Wget.


OPTIONS
	-j 	Debug; print JSON.

	-h 	Show this help.

	-t 	Time series, contract price; select time range with
		argument 1-3; defaults=3.

	-v 	Print this script version."

# Parse options
while getopts ":jhtv" opt; do
	case ${opt} in
		j ) # Print JSON
			PJSON=1
			;;
		h ) # Help
	      		echo -e "${HELP}"
	      		exit 0
	      		;;
		t ) #time series
			tsopt=1
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

#Check for JQ
if ! command -v jq &>/dev/null; then
	printf "JQ is required.\n" 1>&2
	exit 1
elif ! command -v xargs &>/dev/null; then
	printf "Xargs is required.\n" 1>&2
	exit 1
fi

# Test if cURL or Wget is available
if command -v curl &>/dev/null; then
	YOURAPP="curl -sL --compressed"
elif command -v wget &>/dev/null; then
	YOURAPP="wget -qO-"
else
	printf "Package cURL or Wget is needed.\n" 1>&2
	exit 1
fi

#request compressed response
if ! command -v gzip &>/dev/null; then
	printf 'warning: gzip may be required\n' 1>&2
fi


if [[ -n "$tsopt" ]]; then
	[[ ! "$1" =~ ^[0-4]+$ ]] && set -- 3 && echo 'set to default opt 3' 1>&2

	#time series Contracts opt -- Default option
	CONTRACTURL="https://www.theice.com/marketdata/DelayedMarkets.shtml?getHistoricalChartDataAsJson=&marketId=6137574&historicalSpan=$1"
	DATA0="$(${YOURAPP} "${CONTRACTURL}")"
	# Print JSON?
	if [[ -n ${PJSON} ]]; then
		printf "%s\n" "${DATA0}"
		exit
	fi

	printf "Bakkt Contract List\n"
	jq -r '.bars[]|reverse|@tsv' <<< "${DATA0}" |
		tee >(wc -l | xargs echo Entries:)
	exit
fi


# Contracts opt -- Default option
CONTRACTURL='https://www.theice.com/marketdata/DelayedMarkets.shtml?getContractsAsJson=&productId=23808&hubId=26066' 
DATA0="$(${YOURAPP} "${CONTRACTURL}")"

# Print JSON?
if [[ -n ${PJSON} ]]; then
	printf "%s\n" "${DATA0}"
	exit
fi

printf "Bakkt Contract List\n"
jq -r 'reverse[]|"",
	"Market_ID: \(.marketId // empty)",
	"Strip____: \(.marketStrip // empty)",
	"Last_time: \(.lastTime // empty)",
	"End_date_: \(.endDate // empty)",
	"LastPrice: \(.lastPrice // empty)",
	"Change(%): \(.change // empty)",
	"Volume___: \(.volume // empty)"' <<< "${DATA0}"

