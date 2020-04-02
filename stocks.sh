#!/bin/bash
# stocks.sh  -- Stock and index rates in Bash
# v0.1.14  mar/2020  by mountaineerbr

#defaults
#stock
DEFSTOCK="TSLA"

#don't change the following:
export LC_NUMERIC="en_US.UTF-8"

HELP="NAME
	stocks.sh  -- Stock and index rates in Bash


SYNOPSIS
	stocks.sh [STOCK]

	stocks.sh -H [STOCK]

	stocks.sh -ip [INDEX]

	stocks.sh -hlv


 	Fetch realtime rates of stocks and indexes from <financialmodelingprep.com> 
	public APIs (more on price update in the next session).
	
	By default, the script will try to fetch real-time data from the server.
	Otherwise, it uses the same data available for the profile ticker opt-
	ion '-p'.
	
	Check various world indexes with option '-i'. 

	If no stock symbol is given, defaults to ${DEFSTOCK}. Stock and index symbols
	are case-insensitive.


LIMITS
	Cryptocurrency rates will not be implemented.

	Stock prices should be updated in real-time, company profiles hourly, 
	historial prices and others daily. See <financialmodelingprep.com/developer/docs/>. 

	According to discussion at
	<github.com/antoinevulcain/Financial-Modeling-Prep-API/issues/1>:

		\"[..] there are no limit on the number of API requests per day.\"


WARRANTY
	Licensed under the GNU Public License v3 or better and is distributed
	without support or bug corrections.
   	
	This script needs Bash,	cURL or Wget, Gzip and JQ to work properly.

	That is _not_ advisable to depend solely on this script for serious 
	trading. Do your own research!

	If you found this useful, consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


USAGE EXAMPLES

	( 1 ) 	Real-time price of Tesla:
		
		$ stocks.sh TSLA 


	( 2 )   List all symbols and look for oil stocks:

		$ stocks.sh -l | grep Oil


	( 3 )   All major indexes:

		$ stocks.sh -i


	( 4 )   Nasdaq index rate only:

		$ stocks.sh -i .IXIC


OPTIONS
	-h           Show this help page.
	
	-H [STOCK]   Historical prices (daily time-series).

	-i [INDEX]   List major indexes or only a single one, if given.
	
	-j           Debug, prints json.

	-l           List stock symbols and their rates.

	-p [STOCK]   Profile ticker.

	-v           Show this script version."

##functions

#historical prices
histf() {
	DATA="$("${YOURAPP[@]}" "https://financialmodelingprep.com/api/v3/historical-price-full/${1^^}?serietype=line")"
	#print json? (debug)
	if [[ -n  "${PJSON}" ]]; then
		printf "%s\n" "${DATA}"
		exit 0
	fi
	
	HIST="$(jq -r '(.historical[]|"\(.date)  \(.close)")' <<<"${DATA}")"
	printf "%s\n" "${HIST}" | column -et -N'DATE,CLOSE'
	jq -r '"Symbol: \(.symbol)"' <<<"${DATA}"
	printf "Registers: %s\n" "$(wc -l <<<"${HIST}")"

	exit
}

#list stock/index symbols
indexf() {
	#get data
	DATA="$("${YOURAPP[@]}" 'https://financialmodelingprep.com/api/v3/majors-indexes')"
	
	#print json? (debug)
	if [[ -n  "${PJSON}" ]]; then
		printf "%s\n" "${DATA}"
		exit 0
	fi
	
	#decode url codes -- why they do it??
	DATA="$(sed 's/%5E/^/g' <<<"${DATA}")"	
	
	#list one index by symbol
	if jq -er '.majorIndexesList[]|select(.ticker == "'${1^^}'")' <<<"${DATA}" &>/dev/null; then
		jq -r '.majorIndexesList[]|select(.ticker == "'${1^^}'")|.price' <<<"${DATA}"
	#list all major indexes
	else
		#test if stdout is to tty
		[[ -t 1 ]] && TRIMCOL="-TNAME" 
		INDEX="$(jq -r '.majorIndexesList[]|"\(.ticker)=\(.price)=\(.changes)=\(.indexName)"' <<<"${DATA}")"
		sort <<<"${INDEX}" | column -et -s= -N'TICKER,VALUE,CHANGE,NAME' ${TRIMCOL}
		printf 'Indexes: %s\n' "$(wc -l <<<"${INDEX}")"
	fi
	
	exit
}

#list stock/index symbols
listf() {
	#get data
	DATA="$("${YOURAPP[@]}" 'https://financialmodelingprep.com/api/v3/company/stock/list')"
	
	#print json? (debug)
	if [[ -n  "${PJSON}" ]]; then
		printf '%s\n' "${DATA}"
		exit 0
	fi
	
	#test if stdout is to tty
	[[ -t 1 ]] && TRIMCOL='-TNAME' 
	
	LIST="$(jq -r '.symbolsList[]|"\(.symbol)=\(.price)=\(.name)"' <<<"${DATA}")"
	sort <<<"${LIST}" | column -et -s= -N'SYMBOL,PRICE,NAME' ${TRIMCOL}
	printf 'Symbols: %s\n' "$(wc -l <<<"${LIST}")"
	
	exit
}

#simple profile ticker
profilef() {
	#get data
	DATA="$("${YOURAPP[@]}" "https://financialmodelingprep.com/api/v3/company/profile/${1^^}")"

	#print json? (debug)
	if [[ -n  "${PJSON}" ]]; then
		printf '%s\n' "${DATA}"
		exit 0
	fi
	
	#process tocker data
	jq -r '"Profile ticker for \(.symbol)",
	(.profile|
		"CorpName: \(.companyName)",
		"CEO_____: \(.ceo//empty)",
		"Industry: \(.industry)",
		"Sector__: \(.sector)",
		"Exchange: \(.exchange)",
		"Cap_____: \(.mktCap)",
		"LastDiv_: \(.lastDiv)",
		"Beta____: \(.beta)",
		"VolAvg__: \(.volAvg)",
		"Range___: \(.range)",
		"Change%_: \(.changesPercentage)",
		"Change__: \(.changes)",
		"Price___: \(.price)"
	)' <<<"${DATA}"

	exit
}

#test if stock symbol is valid
testsf() {
	if "${YOURAPP[@]}" 'https://financialmodelingprep.com/api/v3/company/stock/list' |
		  jq -r '.symbolsList[].symbol' | grep -q "^\\${1^^}$"; then
		return 0
	else
		printf 'Unsupported stock symbol -- %s\n' "${1^^}" 1>&2
		exit 1
	fi
}

# Parse options
while getopts ':hHijlpv' opt; do
	case ${opt} in
		( h ) #help
			printf '%s\n' "${HELP}"
			exit 0
			;;
		( H ) #historical prices
			HOPT=1
			;;
		( i ) #indexes
			IOPT=1
			;;
		( j ) #debug; print json
			PJSON=1
			;;
		( l ) #list symbols
			LOPT=1
			;;
		( p ) #simple profile ticker
			POPT=1
			;;
		( v ) #version of this script
			grep -m1 '\# v' "${0}"
			exit 0
			;;
		( \? )
			printf 'Invalid option: -%s\n' "${OPTARG}" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

#test for must have packages
if ! command -v jq &>/dev/null; then
	printf "JQ is required.\n" 1>&2
	exit 1
fi
if command -v curl &>/dev/null; then
	YOURAPP=(curl -sL --compressed)
elif command -v wget &>/dev/null; then
	YOURAPP=(wget -qO-)
else
	printf 'cURL or Wget is required.\n' 1>&2
	exit 1
fi

#request compressed response
if ! command -v gzip &>/dev/null; then
	printf 'warning: gzip may be required\n' 1>&2
fi

##call opt functions
#list symbols
[[ -n "${LOPT}" ]] && listf
#major indexes (full list or single index)
[[ -n "${IOPT}" ]] && indexf "${1}"

#set defaults stock symbol if no arg given
if [[ -z "${1}" ]]; then
	set -- "${DEFSTOCK}"
#test symbol
else
	testsf "${1}"
fi

##call opt functions
#company profile ticker
[[ -n "${POPT}" ]] && profilef "${1}"
#historical prices
[[ -n "${HOPT}" ]] && histf "${1}"

#default function, get stock/index real-time rate
DATA="$("${YOURAPP[@]}" "https://financialmodelingprep.com/api/v3/stock/real-time-price/${1^^}")"

#print json? (debug)
if [[ -n  "${PJSON}" ]]; then
	printf '%s\n' "${DATA}"
	exit 0
fi

#test if there is real-time data available,
#otherwise get static data
if [[ "${DATA}" = '{ }' ]]; then
	printf 'No real-time data.\r' 1>&2
	DATA="$("${YOURAPP[@]}" "https://financialmodelingprep.com/api/v3/company/profile/${1^^}")"
	jq -r '.profile.price' <<<"${DATA}"
else
	#process real-time data
	jq -r '.price' <<<"${DATA}"
fi

