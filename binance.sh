#!/bin/bash
# Binance.sh  --  Market rates from Binance public APIs
# v0.9.15  mar/2020  by mountaineerbr

#defaults

#decimal plates
FSTRDEF='%s'    #printf-like price formatting 
#FSTRDEF=8      #eight decimal plates

#server
WHICHB='com'    #'com', 'us' or 'je'

#don't change this
export LC_NUMERIC='en_US.UTF-8'

HELP="NAME
	Binance.sh - Market rates from Binance public APIs


SYNOPSIS
	binance.sh [-NUM|-ff\"NUM\"] [-ju] [AMOUNT] MARKET

	binance.sh [-NUM|-ff\"NUM\"] [-acirsw] [-ju] MARKET
	
	binance.sh [-bbbt] [-ju] MARKET
	
	binance.sh [-dhlv]


	Get the latest data from Binance public APIs.

	This script does not intend to converting crypto currencies, even though 
	it does calculate, say, 10.3 bitcoins in tether, but rather fetching 
	rates for supported markets. That just means it cannot convert BTC to XRP,
	but rather use the XRPBTC market rate. Writing the currency pair separa-
	tely is supoprted, such as 'XRP BTC' but not 'XRP/BTC'

	List of all supported markets with '-l'.

	Choose which Binance server to get data from. Option '-j' uses <binance.je>,
	'-u' uses <binance.us>, otherwise defaults to <binance.com> from Malta.
	Switching servers will only work as long as Binance keeps using the same
	API code scheme.

	To keep trying to reconnect automatically on error or EOF, use option 
	'-a', but beware this option may cause high CPU spinning until reconnec-
	tion is achieved!

	Setting options to use REST APIs instead of websockets update a little 
	slower because REST depend on connecting repeatedly, whereas websockets
	leave an open connection.

	The number of decimal plates is the same received from the server. Set 
	decimal plates with '-f', see example (4). Options '-NUM' are shortcuts
	for '-fNUM', where NUM must be a natural number (1,2,3..).

	It is also possible to add a 'thousands' separator using '-ff', see usage
	example (5). Option '-f' also accepts a printf-like formatting string
	(defaults='%s').

	Some functions use curl/wget to fetch data from REST APIs and some use 
	the websocat package to fetch data from websockets. If no market is gi-
	ven, uses BTCUSDT by defaults. If option '-j' is used, market defaults 
	to BTCEUR and if '-u' is used, defaults to BTCUSD.

  
LIMITS ON WEBSOCKET MARKET STREAMS

	From Binance API website:

		\"A single connection to stream.binance.com is only valid for 24
		hours; expect to be disconnected at the 24 hour mark.\"

	<https://binance-docs.github.io/apidocs/spot/en/#symbol-order-book-ticker>

	
	Use script option '-a' to try reconnecting automatically.


WARRANTY
	Licensed under the GNU Public License v3 or better and is distributed
	without support or bug corrections.
   	
	This script needs Bash, cURL or Wget, Gzip, JQ , Websocat, Lolcat and 
	Coreutils to work properly.

	If you found this useful, consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


BUGS
	Beware of unlimited scrollback buffers for terminal emulators. As lots
	of data is printed, scrollback buffers should be kept small or complete-
	ly unset in order to avoid system freezes.

	If a division operation is given in AMOUNT, such as '1/3 BTCUSDT', bash
	calculator will use its math library and set scale to 20 decimal plates,
	plus one uncertainty digit. in such case, use option '-f' to set scale 
	adequately.


USAGE EXAMPLES
		(1) 	One Bitcoin in Tether:
			
			$ binance.sh btc usdt


			Same using <binance.com> rates:
			
			$ binance.sh -u btc usdt


		(2)     Half a Dash in Binance Coin, using a math expression
			in AMOUNT:
			
			$ binance.sh '(3*0.15)+.05' dash bnb 


		(3)     Price of one XRP in USDC, four decimal plates:
			
			$ binance.sh -f4 xrp usdc 

			$ binance.sh -4 xrp usdc 
			
		
		(4)     Price stream of BTCUSDT, group thousands; print only 
			one decimal plate:
			
			$ binance.sh -s -ff1 btc usdt
			
			$ binance.sh -s -f\"%'.1f\" btc usdt


		(5) 	Order book depth view of ETHUSDT (20 levels on each 
			side), data from <binance.us>:

			$ binance.sh -bbu eth usdt


		(6)     Get rates for all Bitcoin markets, use grep to search 
			for specific markets:
			
			$ binance.sh -l	| grep BTC

			
			OBS: \"grep '^BTC'\" to get markets that start with BTCxxx;
			     \"grep 'BTC$'\" to get markets that  end  with xxxBTC.


OPTIONS
	-NUM 	   Shortcut for simple decimal setting, same as '-fNUM'.

	-a 	   Autoreconnect for websocat options; defaults=unset.

	-b  [LEVELS] 'MKT'   
		   Order book depth; valid limits 5, 10 and 20; defaults=20.
	
	-bb [LEVELS] 'MKT'
		   Calculate bid and ask sizes from order book; max levels 5000-
		   10000; defaults=10000.

	-c  [LIMIT] 'MKT' 
		   Price in columns; optionally, limit number of orders fetched
		   at a time; max=1000; defaults=250.

	-d 	   Some debugging info.

	-f  [NUM|STR]
		   Number of decimal plates 'NUM' or printf-like formatting of
		   prices 'STR'; for use with options '-csw'; defaults=%s (same
		   as received).
	
	-ff [NUM]  
		   Number of decimal plates and adds a thousands separator.

	-h 	   Show this help.

	-i  'MKT'  Detailed information of the trade stream.
	
	-j 	   Use <binance.je> server; defaults=<binance.com>.

	-l 	   List supported markets.
	
	-r 	   Use curl/wget instead of websocat with options '-swi'.

	-s  'MKT'  Stream of latest trades.
	
	-t  'MKT'  Rolling 24h ticker.

	-u 	   Use <binance.us> server; defaults=<binance.com>.
		   
	-v 	   Print script version.
	
	-w 	   Coloured stream of latest trades, requires lolcat."

#functions

#error check
errf() {
	#test for error signals
	if grep -iq -e 'err' -e 'code' <<< "${JSON}"; then
		#set log file
		UNIQ="/tmp/binance_err.log${RANDOM}${RANDOM}"
		
		#print json and log, too
		printf '%s\n' "${JSON}" | tee "${UNIQ}" 1>&2

		printf 'Err detected in JSON.\n' 1>&2
		printf 'Log file at %s\n' "${UNIQ}" 1>&2
		
		exit 1
	fi
}

#-c price in columns
colf() {
	#check if given limit is valid - max 1000
	((${1}-1)) && ((${1}<=1000)) || set -- 250 "${2}" "${3}"
	
	#loop to get prices and print
	while true; do
		#get data
		JSON="$("${YOURAPP[@]}" "https://api.binance.${WHICHB}/api/v3/aggTrades?symbol=${2^^}${3^^}&limit=${1}")"
		
		#check for errors
		errf

		#process data
		jq -r '.[] | .p' <<< "${JSON}" | awk '{ printf "'${FSTR}'\n", $0 }' | column 
		printf '\n'
	done
}

#-i price and trade info
infof() {
	#-r use curl
	curlmode() {
		#heading
		printf -- 'Rate, quantity and time (%s).\n' "${2^^}${3^^}"
		
		#print data in one column and update regularly
		while true; do
			#get data
			JSON=$("${YOURAPP[@]}" "https://api.binance.${WHICHB}/api/v3/trades?symbol=${2^^}${3^^}&limit=1")
			
			#check for errors
			errf
			
			#process data
			RATE="$(jq -r '.[] | .price' <<< "${JSON}")"
			QQT="$(jq -r '.[] | .quoteQty' <<< "${JSON}")"
			TS="$(jq -r '.[] | .time' <<< "${JSON}" | cut -c-10)"
			DATE="$(date -d@"${TS}" '+%T%Z')"
			
			#print
			printf "\n${FSTR} \t%'.f\t%s" "${RATE}" "${QQT}" "${DATE}"   
		done
		exit 0
	}
	[[ -n "${CURLOPT}" ]] && curlmode "${@}"

	#websocat mode
	
	#heading
	printf -- 'Detailed stream of %s%s\n' "${2^^}" "${3^^}"
	printf -- 'Price, quantity and time.\n'
	
	#open websocket
	"${WEBSOCATC[@]}" "${WSSADD}${2,,}${3,,}@aggTrade" | jq --unbuffered -r '"P: \(.p|tonumber)  \tQ: \(.q)     \tPQ: \((.p|tonumber)*(.q|tonumber)|round)    \t\(if .m == true then "MAKER" else "TAKER" end)\t\(.T/1000|strflocaltime("%H:%M:%S%Z"))"'
}

#-s stream of prices
socketf() {
	#-r use curl
	curlmode() { 
		#heading
		printf -- 'Rate for %s%s.\n' "${2^^}" "${3^^}"
		while true; do
			JSON="$("${YOURAPP[@]}" "https://api.binance.${WHICHB}/api/v3/aggTrades?symbol=${2^^}${3^^}&limit=1")"
	 		errf
			jq -r '.[] | .p' <<< "${JSON}" | awk '{ printf "\n'${FSTR}'", $1 }' | "${COLORC[@]}"
		done
		exit 0
		}
	[[ -n "${CURLOPT}" ]] && curlmode "${@}"

	#websocat Mode
	#heading
	printf 'Stream of %s%s\n' "${2^^}" "${3^^}"
	
	#open websocket
	"${WEBSOCATC[@]}" "${WSSADD}${2,,}${3,,}@aggTrade" | jq --unbuffered -r '.p' | xargs -n1 printf "\n${FSTR}" | "${COLORC[@]}"
	#stdbuf -i0 -o0 -e0 cut -c-8
}

#-b depth view of order book
bookdf() {
	#test if user set depth limit
	if [[ "${1}" -ne 5 ]] && [[ "${1}" -ne 10 ]] && [[ "${1}" -ne 20 ]]; then
		[[ "${1}" -ne 1 ]] && printf 'Warning: valid limits are 5, 10 and 20\n' 1>&2
		set -- 20 "${2}" "${3}"
	fi
	
	#heading
	printf 'Order book %s%s\n' "${2,,}" "${3,,}"
	printf 'Price and quantity\n'
	
	#open websocket and process data
	"${WEBSOCATC[@]}" "${WSSADD}${2,,}${3,,}@depth${1}@100ms" |
	jq -r --arg FCUR "${2^^}" --arg TCUR "${3^^}" '
		"\nORDER BOOK \($FCUR)\($TCUR)",
		"",
		(.asks|[.[range(1;length)]]|reverse[]|
			"\t\(.[0]|tonumber)    \t\(.[1]|tonumber)"
		),
		(.asks[0]|"     > \(.[0]|tonumber)      \t\(.[1]|tonumber)"),
		(.bids[0]|"     < \(.[0]|tonumber)      \t\(.[1]|tonumber)"),
		(.bids|.[range(1;length)]|
			"\t\(.[0]|tonumber)    \t\(.[1]|tonumber)"
		)'
	printf '\n'
}
#"\tPRICE    \tQTY",

#-bb order book total sizes
booktf() {
	#check if user set limit
	if [[ "${1}" -eq 1 ]] || [[ "${1}" -gt 10000 ]]; then
		[[ "${1}" -ne 1 ]] && printf 'Warning: max levels 10000\n' 1>&2
		set -- 10000 "${2}" "${3}"
	fi

	#heading
	printf 'Order book sizes\n\n'

	#get data
	BOOK="$("${YOURAPP[@]}" "https://api.binance.${WHICHB}/api/v3/depth?symbol=${2^^}${3^^}&limit=${1}")"
	
	#process data
	#bid levels and total size
	BIDS=($(jq -r '.bids[]|.[1]' <<<"${BOOK}")) 
	BIDSL="$(printf '%s\n' "${BIDS[@]}" | wc -l)"
	BIDST="$(bc -l <<<"${BIDS[*]/%/+}0")"
	BIDSQUOTE=($(jq -r '.bids[]|((.[0]|tonumber)*(.[1]|tonumber))' <<<"${BOOK}")) 
	BIDSQUOTET="$(bc -l <<<"scale=2;(${BIDSQUOTE[*]/%/+}0)/1")"
	
	#ask levels and total size
	ASKS=($(jq -r '.asks[]|.[1]' <<<"${BOOK}"))
	ASKSL="$(printf '%s\n' "${ASKS[@]}" | wc -l)"
	ASKST="$(bc -l <<<"${ASKS[*]/%/+}0")"
	ASKSQUOTE=($(jq -r '.asks[]|((.[0]|tonumber)*(.[1]|tonumber))' <<<"${BOOK}")) 
	ASKSQUOTET="$(bc -l <<<"scale=2;(${ASKSQUOTE[*]/%/+}0)/1")"
	
	#total levels and total sizes
	TOTLT="$(bc -l <<<"${BIDSL}+${ASKSL}")"
	TOTST="$(bc -l <<<"${BIDST}+${ASKST}")"
	TOTQUOTET="$(bc -l <<<"${BIDSQUOTET}+${ASKSQUOTET}")"

	#bid/ask rate
	BARATE="$(bc -l <<<"scale=4;${BIDST}/${ASKST}")"
	
	#print stats
	#ratio  #printf 'BID/ASK  %s\n\n' "${BARATE}"
	
	#table
	column -ts= -N"${2^^}${3^^},SIZE,QUOTESIZE,LEVELS" -TSIZE <<-!
	ASKS=${ASKST}=${ASKSQUOTET}=${ASKSL}
	BIDS=${BIDST}=${BIDSQUOTET}=${BIDSL}
	TOTAL=${TOTST}=${TOTQUOTET}=${TOTLT}
	BID/ASK=${BARATE}
	!
}

#-t 24-h ticker
tickerf() {
	#open websocket and process data
	"${WEBSOCATC[@]}" "${WSSADD}${2,,}${3,,}@ticker" |
		jq -r '"","---",
			.s,.e,(.E/1000|strflocaltime("%H:%M:%S%Z")),
			"TimeRang: \(((.C-.O)/1000)/(60*60)) hrs",
			"",
			"Price",
			"Change__: \(.p|tonumber)  \(.P|tonumber)%",
			"Weig.Avg: \(.w|tonumber)",
			"Open____: \(.o|tonumber)",
			"High____: \(.h|tonumber)",
			"Low_____: \(.l|tonumber)",
			"Base_Vol: \(.v|tonumber)",
			"QuoteVol: \(.q|tonumber)",
			"",
			"Trades",
			"Number__: \(.n)",
			"First_ID: \(.F)",
			"Last__ID: \(.L)",
			"FirstT-1: \(.x)",
			"Best_Bid: \(.b|tonumber)  Qty: \(.B)",
			"Best_Ask: \(.a|tonumber)  Qty: \(.A)",
			"LastTrad: \(.c|tonumber)  Qty: \(.Q)"'
	printf '\n'
}

#-l list markets and prices
lcoinsf() {
	#get data
	LDATA="$("${YOURAPP[@]}" "https://api.binance.${WHICHB}/api/v3/ticker/price")"
	
	#process data
	jq -r '.[] | "\(.symbol)=\(.price)"' <<< "${LDATA}"| sort | column -s '=' -et -N 'Market,Rate'
	
	#stats
	printf 'Markets: %s\n' "$(jq -r '.[].symbol' <<< "${LDATA}"| wc -l)"
	printf '<https://api.binance.%s/api/v3/ticker/price>\n' "${WHICHB}"

	exit
}


#parse options
while getopts ':1234567890abcdf:hjlistuwvr' opt; do
	case ${opt} in
		( [0-9] ) #decimal setting, same as '-fNUM'
			FSTR="${FSTR}${opt}"
			;;
		( a ) 	#autoreconnect
			RETRY1='-'
			RETRY2='autoreconnect:'
			;;
		( c ) #price in columns
			COPT=1
			;;
		( b ) #order book depth view
			[[ -z "${BOPT}" ]] && BOPT=1 ||	BOPT=2
			;;
		( d ) #print lines that fetch data
			printf 'Script cmds to fetch data:\n'
			grep -e 'YOURAPP' -e 'WEBSOCATC' <"${0}" | sed -e 's/^[ \t]*//' | sort
			exit 0
			;;
		( f ) #scale and printf-like format
			[[ "${OPTARG}" =~ f ]] && FSTRSEP=1 
			FSTR="${OPTARG#f}"
			[[ "${OPTARG}" = f ]] && FSTR=0
			;;
		( h ) #help
			printf '%s\n' "${HELP}"
			exit 0
			;;
		( i ) #detailed latest trade information
			IOPT=1
			;;
		( j ) #binance jersey
			WHICHB='je'
			;;
		( l ) #list markets
			LOPT=1
			;;
		( r ) #curl instead of websocat
			CURLOPT=1
			;;
		( s ) #stream of trade prices
			COLORC=(cat)
			SOPT=1
			;;
		( t ) #rolling ticker 
			TOPT=1
			;;
		( u ) #binance us
			WHICHB='us'
			;;
		( v ) #script version
			grep -m1 '\# v' "${0}"
			exit 0
			;;
		( w ) #coloured stream of trade prices
			SOPT=1
			COLORC=(lolcat -p 2000 -F 5)
			;;
		( \? )
			printf 'Invalid option: -%s\n' "${OPTARG}" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

#set default scale if no custom scale
if [[ -z ${FSTR} ]]; then
	FSTR="${FSTRDEF}"
elif [[ "${FSTR}" =~ ^[0-9]+$ ]]; then
	if [[ -n "${FSTRSEP}" ]]; then
		FSTR="%'.${FSTR}f"
	else
		FSTR="%.${FSTR}f"
	fi
else
	FSTR="${FSTR}"
fi

#must have packages
if ! command -v jq &>/dev/null; then
	printf 'JQ is required.\n' 1>&2
	exit 1
fi
if command -v curl &>/dev/null; then
	YOURAPP=(curl -sL --compressed)
elif command -v wget &>/dev/null; then
	YOURAPP=(wget -qO-)
else
	printf 'Curl or wget is required.\n' 1>&2
	exit 1
fi

#request compressed response
if ! command -v gzip &>/dev/null; then
	printf 'warning: gzip may be required\n' 1>&2
fi

if [[ -n "${IOPT}${SOPT}${BOPT}${TOPT}" ]] &&
	[[ -z "${CURLOPT}" ]] && ! command -v websocat &>/dev/null; then
	printf 'Websocat is required.\n' 1>&2
	exit 1
fi

#call opt functions
#list of markets
[[ -n "${LOPT}" ]] && lcoinsf

#set websocket
#websocat command
WEBSOCATC=(websocat -nt --ping-interval 20 -E --ping-timeout 42 ${RETRY1})

#websocket address
WSSADD="${RETRY2}wss://stream.binance.${WHICHB}:9443/ws/"

#arrange arguments
#if first arg does not have numbers OR isn't a valid bc expression
if ! [[ "${1}" =~ [0-9] ]] ||
	[[ -z "$(bc -l <<< "${1}" 2>/dev/null)" ]]; then
	set -- 1 "${@:1:2}"
fi

#set btc as 'from_currency' for market code formation
if [[ -z ${2} ]]; then
	set -- "${1}" BTC
fi

#get market symbol list
MARKETS="$("${YOURAPP[@]}" "https://api.binance.${WHICHB}/api/v3/ticker/price" | jq -r '.[].symbol')"

#set to_currency if none given
#or if input is a valid market
if [[ -z ${3} ]] && ! grep -qi "^${2}$" <<< "${MARKETS}"; then
	#copy original user input, if any
	USERIN="${2}${3}"

	#try to help
	if [[ "${WHICHB}" = us ]]; then
		set -- "${1}" "${2}" USD
	elif [[ "${WHICHB}" = je ]]; then
		set -- "${1}" "${2}" EUR
	else
		set -- "${1}" "${2}" USDT
	fi
fi

#test if market is valid
if ! grep -qi "^${2}${3}$" <<< "${MARKETS}"; then
	if [[ -n "${USERIN}" ]]; then
		printf 'Err: not a supported market: %s\n' "${USERIN^^}" 1>&2
	else
		printf 'Err: not a supported market: %s%s\n' "${2^^}" "${3^^}" 1>&2
	fi

	exit 1
#print reminder message that the script needed to help
#user input to form a market pair
#elif [[ -n "${USERIN}" ]]; then
#	printf 'Autoset: %s%s\n' "${2^^}" "${3^^}" 1>&2
fi

#call opt functions
#detailed trade info
if [[ -n "${IOPT}" ]]; then
	infof "${@}"
#price websocket stream
elif [[ -n "${SOPT}" ]]; then
	socketf "${@}"
#order book depth opts
#order book depth 10
elif [[ "${BOPT}" -eq 1 ]]; then
	bookdf "${@}"
#order book total sizes
elif [[ "${BOPT}" -eq 2 ]]; then
	booktf "${@}"
#24-h ticker
elif [[ -n "${TOPT}" ]]; then
	tickerf "${@}"
#price in columns
elif [[ -n "${COPT}" ]]; then
	colf "${@}"
#default function -- market rates
else
	#get data
	BRATE=$("${YOURAPP[@]}" "https://api.binance.${WHICHB}/api/v3/ticker/price?symbol=${2^^}${3^^}" | jq -r ".price")

	#calc and printf results
	bc -l <<< "(${1})*${BRATE}" | xargs printf "${FSTR}\n"
fi

