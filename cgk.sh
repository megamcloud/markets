#!/bin/bash
# cgk.sh -- coingecko.com api access
# v0.10.45  apr/2020  by mountaineerbr

#defaults

#default crypto, defaults=btc
DEFCUR=btc

#vs currency, defaults=usd
DEFVSCUR=usd

#scale, defaults=16
SCLDEFAULTS=16

#don't change these
export LC_NUMERIC="en_US.UTF-8"

#troy ounce to gram ratio
TOZ='31.1034768'

## Manual and help
HELP_LINES="NAME
	Cgk.sh -- Currency Converter and Market Stats
		  Coingecko.com API Access


SYNOPSIS
	cgk.sh [-g|-sNUM] [AMOUNT] 'FROM_CURRENCY' [VS_CURRENCY] 
	cgk.sh -d [CRYPTO]
	cgk.sh -ee [-p]
	cgk.sh -t [-pNUM] 'CRYPTO' [VS_CURRENCY]
	cgk.sh -m [VS_CURRENCY]
	cgk.sh [-hlv]


DESCRIPTION
	This programme fetches updated crypto and bank currency rates from Coin
	Gecko.com and can convert any amount of one supported currency into an-
	other. FROM_CURRENCY is a cryptocurrency and symbol or CoinGecko IDs can
	be used.

	List supported symbols with option \"-l\". VS_CURRENCY is a fiat or metal 
	and defaults to ${DEFVSCUR,,}. Currently, only about 53 bank currencies
	(fiat) are supporterd, plus gold and silver.
	
	Central bank currency conversions are not supported directly, but we can
	derive them undirectly, for e.g. USD vs CNY. As CoinGecko updates fre-
	quently, it is one of the best APIs for bank currency rates, too.

	Use option \"-g\" to convert precious metal rates using grams instead of 
	troy ounces for precious metals (${TOZ}grams/troyounce).

	Default precision is ${SCLDEFAULTS} and can be adjusted with option \"-s\" (scale).

	<coingecko.com> api rate limit is currently 100 requests/minute.
	

ABBREVIATIONS
	Some functions function uses abbreviations to indicate data type.

		EXID 		Exchange identifier
		EX 	 	Exchange name
		INC? 		Incentives for trading?
		NORM 		Normalised volume
		RNK 		Trust rank
		SCORE 		Trust score

	
	For more information, such as normal and normalized volume, check:

		<https://blog.coingecko.com/trust-score/>


24H ROLLING TICKER FUNCTION \"-t\" 
	Some currency convertion data is available for use with the Market Cap 
	Function \"-m\". You can choose which currency to display data, when 
	available, from the table below:

 	AED     BMD     CLP     EUR     INR     MMK     PKR     THB     VND
 	ARS     BNB     CNY     GBP     JPY     MXN     PLN     TRY     XAG
 	AUD     BRL     CZK     HKD     KRW     MYR     RUB     TWD     XAU
 	BCH     BTC     DKK     HUF     KWD     NOK     SAR     UAH     XDR
 	BDT     CAD     EOS     IDR     LKR     NZD     SEK     USD     XLM
	BHD     CHF     ETH     ILS     LTC     PHP     SGD     VEF     XRP
        								ZAR


	Otherwise, the market capitulation table will display data in various
	currencies in some fields by defaults.


WARRANTY
	Licensed under the GNU Public License v3 or better. It is distributed 
	without support or bug corrections. This programme needs Bash, cURL or 
	Wget, JQ, Coreutils and Gzip to work properly.
	
	It  is  _not_ advisable to depend solely on CoinGecko rates for serious 
	trading.
	
	If you found this useful, consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


USAGE EXAMPLES		
		(1)     One Bitcoin in US Dollar:
			
			$ cgk.sh btc
			
			$ cgk.sh 1 btc usd


		(2)     100 ZCash in Digibyte with 8 decimal plates:
			
			$ cgk.sh -s8 100 zcash digibyte 
			
			$ cgk.sh -8 100 zec dgb 

		
		(3)     One thousand Brazilian Real in US Dollar with 3 decimal
			plates and using math expression in AMOUNT:
			
			$ cgk.sh -3 '101+(2*24.5)+850' brl usd 


		(4)    One gram of gold in US Dollars:
					
			$ cgk.sh -g xau usd 


		(5)    Tickers of any Ethereum pair from all exchanges;
					
			$ cgk.sh -t eth 
			
			TIP: use Less with opion -S (--chop-long-lines) or the 
			\"Most\" pager for scrolling horizontally:

			$ cgk.sh -t eth | less -S


		(6) 	Market cap function, show data for Chinese CNY:

			$ cgk.sh -m cny


OPTIONS
	-NUM 	  Shortcut for scale setting, same as \"-sNUM\".

	-b 	  Bank currency function, converts between bank curren-
		  cies and precious metals; automatically set when need-
		  ed; script runs faster when used with non sup ported
		  markets.

	-d [CRYPTO]
		  Dominance of a single crypto currency in percentage.

	-e 	  Exchange information; number of pages to fetch with option \"-p\";
		  pass \"-ee\" to print a list of exchange names and IDs only.

	-g 	  Use grams instead of troy ounces; only for precious metals.
		
	-h 	  Show this help.

	-j 	  Debug; print JSON.

	-l 	  List supported currencies.

	-m [VS_CURRENCY]
		  Market capitulation table; defaults=USD.

	-p [NUM]
		  Number of pages retrieved from the server; each page may con-
		  tain 100 results; use with options \"-e\" and \"-t\"; defaults=4.
	 	
	-s [NUM]  Scale setting (decimal plates); defaults=${SCLDEFAULTS}.
	
	-t 	  Tickers of a single cryptocurrency from all suported exchanges
		  and all its pairs; can use with \"-p\".
		
	-v 	  Show this programme version."


## Functions
## -m Market Cap function		
#-d dominance opt
mcapf() {
	# Check if input has a defined vs_currency
	if [[ -z "${1}" ]]; then
		NOARG=1
		set -- "${DEFVSCUR,,}"
	fi
	# Get Data 
	CGKGLOBAL="$(${YOURAPP} "https://api.coingecko.com/api/v3/global" -H  "accept: application/json")"
	# Check if input is a valid vs_currency for this function
	if ! jq -r '.data.total_market_cap|keys[]' <<< "${CGKGLOBAL}" | grep -qi "^${1}$"; then
		printf "Using USD. Not supported -- %s.\n" "${1^^}" 1>&2
		NOARG=1
		set -- usd
	fi

	#-d only dominance?
	if [[ -n "${DOMOPT}" ]] && [[ -n "${1}" ]] && 
			DOM="$(jq -e ".data.market_cap_percentage.${1,,}//empty" <<< "${CGKGLOBAL}")"; then
		
		# Print JSON?
		if [[ -n ${PJSON} ]]; then
			printf "%s\n" "${CGKGLOBAL}"
			exit
		fi

		printf "%.${SCL}f %%\n" "${DOM}"
		
		exit 
	elif [[ -n "${DOMOPT}" ]]; then
		printf 'Symbol\tDominance%%\n'
		jq -r '.data.market_cap_percentage|to_entries[] | [.key, .value] | @tsv' <<< "${CGKGLOBAL}"
		total="$(jq -r '.data.market_cap_percentage|to_entries[] | .value' <<< "${CGKGLOBAL}" |	paste -sd+ | bc -l)"
		printf 'Sum:\t%.13f\n' "$total"
		exit
	fi
	#DOMINANCEARRAY=($(jq -r '.data.market_cap_percentage | keys_unsorted[]' <<< "${CGKGLOBAL}"))

	MARKETGLOBAL="$(${YOURAPP} "https://api.coingecko.com/api/v3/coins/markets?vs_currency=${1,,}&order=market_cap_desc&per_page=10&page=1&sparkline=false")"

	# Print JSON?
	if [[ -n ${PJSON} ]]; then
		printf "%s\n" "${CGKGLOBAL}"
		printf 'Second json:\n' 1>&2
		sleep 4
		printf "%s\n" "${MARKETGLOBAL}"
		exit
	fi

	#timestamp
	CGKTIME=$(jq -r '.data.updated_at' <<< "${CGKGLOBAL}")
	{ # Avoid erros being printed
	cat <<-!
	## CRYPTO MARKET STATS
	$(date -d@"$CGKTIME" "+#  %FT%T%Z")
	## Markets : $(jq -r '.data.markets' <<< "${CGKGLOBAL}")
	## Cryptos : $(jq -r '.data.active_cryptocurrencies' <<< "${CGKGLOBAL}")
	## ICOs Stats
	 # Upcoming: $(jq -r '.data.upcoming_icos' <<< "${CGKGLOBAL}")
	 # Ongoing : $(jq -r '.data.ongoing_icos' <<< "${CGKGLOBAL}")
	 # Ended   : $(jq -r '.data.ended_icos' <<< "${CGKGLOBAL}")
	!

	printf "\n## Total Market Cap\n"
	printf " # Equivalent in\n"
	printf "    %s    : %'22.2f\n" "${1^^}" "$(jq -r ".data.total_market_cap.${1,,}" <<< "${CGKGLOBAL}")"
	if [[ -n "${NOARG}" ]]; then
		printf "    EUR    : %'22.2f\n" "$(jq -r '.data.total_market_cap.eur' <<< "${CGKGLOBAL}")"
		printf "    GBP    : %'22.2f\n" "$(jq -r '.data.total_market_cap.gbp' <<< "${CGKGLOBAL}")"
		printf "    BRL    : %'22.2f\n" "$(jq -r '.data.total_market_cap.brl' <<< "${CGKGLOBAL}")"
		printf "    JPY    : %'22.2f\n" "$(jq -r '.data.total_market_cap.jpy' <<< "${CGKGLOBAL}")"
		printf "    CNY    : %'22.2f\n" "$(jq -r '.data.total_market_cap.cny' <<< "${CGKGLOBAL}")"
		printf "    XAU(oz): %'22.2f\n" "$(jq -r '.data.total_market_cap.xau' <<< "${CGKGLOBAL}")"
		printf "    BTC    : %'22.2f\n" "$(jq -r '.data.total_market_cap.btc' <<< "${CGKGLOBAL}")"
		printf "    ETH    : %'22.2f\n" "$(jq -r '.data.total_market_cap.eth' <<< "${CGKGLOBAL}")"
		printf "    XRP    : %'22.2f\n" "$(jq -r '.data.total_market_cap.xrp' <<< "${CGKGLOBAL}")"
	fi
	printf " # Change(%%USD/24h): %.4f %%\n" "$(jq -r '.data.market_cap_change_percentage_24h_usd' <<< "${CGKGLOBAL}")"

	cat <<-!

	## Market Cap per Coin
	# SYMBOL      CAP(${1^^})            CHANGE(24h)
	$(jq -r '.[]|"\(.symbol) \(.market_cap)  \(.market_cap_change_percentage_24h)"' <<< "${MARKETGLOBAL}"  | awk '{ printf "  # %s  %'"'"'22.2f    %.4f%%\n", toupper($1) , $2 , $3 , $4 }')

	## Dominance (Top 10)
	$(jq -r '.data.market_cap_percentage | keys_unsorted[] as $k | "\($k) \(.[$k])"' <<< "${CGKGLOBAL}" | awk '{ printf "  # %s    : %8.4f%%\n", toupper($1), $2 }')
	$(jq -r '(100-(.data.market_cap_percentage|add))' <<< "${CGKGLOBAL}" | awk '{ printf "  # Others : %8.4f%%\n", $1 }')
	!

	printf "\n## Market Volume (Last 24H)\n"
	printf " # Equivalent in\n"
	printf "    %s    : %'22.2f\n" "${1^^}" "$(jq -r ".data.total_volume.${1,,}" <<< "${CGKGLOBAL}")"
	if [[ -n "${NOARG}" ]]; then
		printf "    EUR    : %'22.2f\n" "$(jq -r '.data.total_volume.eur' <<< "${CGKGLOBAL}")"
		printf "    GBP    : %'22.2f\n" "$(jq -r '.data.total_volume.gbp' <<< "${CGKGLOBAL}")"
		printf "    BRL    : %'22.2f\n" "$(jq -r '.data.total_volume.brl' <<< "${CGKGLOBAL}")"
		printf "    JPY    : %'22.2f\n" "$(jq -r '.data.total_volume.jpy' <<< "${CGKGLOBAL}")"
		printf "    CNY    : %'22.2f\n" "$(jq -r '.data.total_volume.cny' <<< "${CGKGLOBAL}")"
		printf "    XAU(oz): %'22.2f\n" "$(jq -r '.data.total_volume.xau' <<< "${CGKGLOBAL}")"
		printf "    BTC    : %'22.2f\n" "$(jq -r '.data.total_volume.btc' <<< "${CGKGLOBAL}")"
		printf "    ETH    : %'22.2f\n" "$(jq -r '.data.total_volume.eth' <<< "${CGKGLOBAL}")"
		printf "    XRP    : %'22.2f\n" "$(jq -r '.data.total_volume.xrp' <<< "${CGKGLOBAL}")"
	fi
	
	cat <<-!

	## Market Volume per Coin (Last 24H)
	# SYMBOL      VOLUME                  CHANGE
	$(jq -r '.[]|"\(.symbol) \(.total_volume) '${1^^}' \(.market_cap_change_percentage_24h)"' <<< "${MARKETGLOBAL}"  | awk '{ printf "  # %s   %'"'"'22.2f %s    %.4f%%\n", toupper($1) , $2 , $3 , $4 }')

	## Supply and All Time High
	# SYMBOL       CIRCULATING            TOTAL SUPPLY
	$(jq -r '.[]|"\(.symbol) \(.circulating_supply) \(.total_supply)"' <<< "${MARKETGLOBAL}"  | awk '{ printf "  # %s      %'"'"'22.2f   %'"'"'22.2f\n", toupper($1) , $2 , $3 }')

	## Price Stats (${1^^})
	$(jq -r '.[]|"\(.symbol) \(.high_24h) \(.low_24h) \(.price_change_24h) \(.price_change_percentage_24h)"' <<< "${MARKETGLOBAL}"  | awk '{ printf "  # %s=%s=%s=%s=%.4f%%\n", toupper($1) , $2 , $3 , $4 , $5 }' | column -t -s"=" -N"  # SYMBOL,HIGH(24h),LOW(24h),CHANGE,CHANGE")

	## All Time Highs (${1^^})
	$(jq -r '.[]|"\(.symbol) \(.ath) \(.ath_change_percentage) \(.ath_date)"' <<< "${MARKETGLOBAL}"  | awk '{ printf "  # %s=%s=%.4f%%= %s\n", toupper($1) , $2 , $3 , $4 }' | column -t -s'=' -N'  # SYMBOL,PRICE,CHANGE,DATE')
	!

	# Avoid erros being printed
	} 2>/dev/null
}

#warning message for more columns
warnf() { printf "OBS: more columns needed to print more data\n" 1>&2;}

## -e Show Exchange info function
exf() { # -ee Show Exchange list
	if [[ "${EXOPT}" -eq 2 ]]; then
		ELIST="$(${YOURAPP} "https://api.coingecko.com/api/v3/exchanges/list")"
		# Print JSON?
		if [[ -n ${PJSON} ]]; then
			printf "%s\n" "${ELIST}"
			exit
		fi
		jq -r '.[]|"\(.id)=\(.name)"' <<< "${ELIST}" | column -et -s'=' -N"EXCHANGE_ID,EXCHANGE_NAME"
		printf "Exchanges: %s.\n" "$(jq -r '.[].id' <<< "${ELIST}" | wc -l)"
		exit
	fi

	# Test screen width
	# if stdout is redirected; skip this
	if ! [[ -t 1 ]]; then
		true
	elif test "$(tput cols)" -lt "85"; then
		COLCONF="-HINC?,COUNTRY,EX -TEXID"
		warnf
	elif test "$(tput cols)" -lt "115"; then
		COLCONF="-HINC?,EX -TCOUNTRY,EXID"
		warnf
	else
		COLCONF="-TCOUNTRY,EXID,EX"
	fi

	#Get pages with exchange info
	# Print JSON?
	if [[ -n ${PJSON} ]]; then
		${YOURAPP} "https://api.coingecko.com/api/v3/exchanges?page=1"
		exit
	fi
	printf "Table of Exchanges\n"
	

	head="$(${YOURAPP2} "https://api.coingecko.com/api/v3/exchanges" 2>&1 | grep -ie "total:" -e "per-page:" | sort -r)"


	total="$(grep -F total <<<"$head"| grep -o '[0-9]*')"
	ppage="$(grep -F page <<<"$head"| grep -o '[0-9]*')"
	[[ -n "${TPAGES}" ]] || TPAGES="$(bc <<<"scale=0;($total/$ppage)+1")"

	printf '%s\n' "$head"

	for ((i=TPAGES;i>0;i--)); do
		printf "Page %s of %s\r" "${i}" "${TPAGES}" 1>&2
		${YOURAPP} "https://api.coingecko.com/api/v3/exchanges?page=${i}" | jq -r 'reverse[] | "\(if .trust_score_rank == null then "??" else .trust_score_rank end)=\(if .trust_score == null then "??" else .trust_score end)=\(.id)=[\(.trade_volume_24h_btc)]=\(.trade_volume_24h_btc_normalized)=\(if .has_trading_incentive == true then "yes" else "no" end)=\(if .year_established == null then "??" else .year_established end)=\(if .country != null then .country else "??" end)=\(.name)"' |
			column -et -s'=' -N"RNK,SCORE,EXID,VOL24H.BTC,NORM.VOL,INC?,YEAR,COUNTRY,EX" ${COLCONF}
	done
	# Check if CoinEgg still has a weird "en_US" in its name that havocks table
}

## Bank currency rate function
bankf() {
	unset BANK FMET TMET
	export TRYBANK=1
	# Grep possible currency ids
	if jq -r '.[],keys[]' <"${CGKTEMPLIST1}" | grep -qi "^${2}$"; then
		changevscf "${2}" 2>/dev/null
		MAYBE1="${GREPID}"
	fi
	if jq -r '.[],keys[]' <"${CGKTEMPLIST1}" | grep -qi "^${3}$"; then
		changevscf "${3}" 2>/dev/null
		MAYBE2="${GREPID}"
	fi

	# Get CoinGecko JSON
	CGKRATERAW="$(${YOURAPP} "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,${2,,},${3,,},${MAYBE1},${MAYBE2}&vs_currencies=btc,${2,,},${3,,},${MAYBE1},${MAYBE2}")"
	# Print JSON?
	if [[ -n ${PJSON} ]]; then
		printf "%s\n" "${CGKRATERAW}"
		exit
	fi
	export CGKRATERAW
	# Get rates to from_currency anyways
	if [[ "${2,,}" = "btc" ]]; then
		BTCBANK=1
	elif ! BTCBANK="$("${0}" "${2,,}" btc 2>/dev/null)"; then
		BTCBANK="(1/$("${0}" bitcoin "${2,,}"))" || exit 1
	fi
	# Get rates to vs_currency anyways
	if [[ "${3,,}" = "btc" ]]; then
		BTCTOCUR=1
	elif ! BTCTOCUR="$("${0}" "${3,,}" btc 2>/dev/null)"; then
		BTCTOCUR="(1/$("${0}" bitcoin "${3,,}"))" || exit 1
	fi
	# Timestamp? No timestamp for this API
	# Calculate result
	# Precious metals in grams?
	ozgramf "${2}" "${3}"
	RESULT="$(bc -l <<< "(((${1})*${BTCBANK})/${BTCTOCUR})${GRAM}${TOZ}")"
	printf "%.${SCL}f\n" "${RESULT}"
}

## -t Ticker Function
tickerf() {
	
	## Trap temp cleaning functions
	trap "rm1f; exit" EXIT SIGINT
	# Test screen width
	# if stdout is redirected; skip this
	if ! [[ -t 1 ]]; then
		true
	elif [[ "$(tput cols)" -lt "110" ]]; then
		COLCONF="-HEX,L.TRADE -TVOL,MARKET,SPD%"
		warnf
	else
		COLCONF="-TL.TRADE,EX,MARKET,VOL,SPD%,P.USD"
		warnf
	fi

	# Start print Heading
	printf "Tickers for %s\n" "${CODE1^^}" 

	#calc how many result pages
	head="$(${YOURAPP2} "https://api.coingecko.com/api/v3/coins/${2,,}/tickers" 2>&1 | grep -Fie "total:" -e "per-page:" | sort -r)"
	total="$(grep -F total <<<"$head"| grep -o '[0-9]*')"
	ppage="$(grep -F page <<<"$head"| grep -o '[0-9]*')"
	[[ -n "${TPAGES}" ]] || TPAGES="$(bc <<<"scale=0;($total/$ppage)+1")"

	printf '%s\n' "$head"

	# Print JSON?
	if [[ -n ${PJSON} ]]; then
		${YOURAPP2} "https://api.coingecko.com/api/v3/coins/${2,,}/tickers"
		${YOURAPP} "https://api.coingecko.com/api/v3/coins/${2,,}/tickers?page=${i}"
		exit
	fi

	for ((i=TPAGES;i>0;i--)); do
		printf "Page %s of %s..\r" "${i}" "${TPAGES}" 1>&2
		${YOURAPP} "https://api.coingecko.com/api/v3/coins/${2,,}/tickers?page=${i}" | jq -r '.tickers[]|"\(.base)/\(.target)=\(.last)=\(if .bid_ask_spread_percentage ==  null then "??" else .bid_ask_spread_percentage end)=\(.converted_last.btc)=\(.converted_last.usd)=\(.volume)=\(.market.identifier)=\(.market.name)=\(.last_traded_at)"' |
			column -s= -et -N"MARKET,PRICE,SPD%,P.BTC,P.USD,VOL,EXID,EX,L.TRADE" ${COLCONF}
	done
}

## -l Print currency lists
listsf() {
	FCLISTS="$(${YOURAPP} "https://api.coingecko.com/api/v3/coins/list")"	
	VSCLISTS="$(${YOURAPP} "https://api.coingecko.com/api/v3/simple/supported_vs_currencies")"	
	# Print JSON?
	if [[ -n ${PJSON} ]]; then
		printf "%s\n\n" "${FCLISTS}"
		printf "%s\n" "${VSCLISTS}"
		exit
	fi
	printf "List of supported FROM_CURRENCIES (cryptos)\n"
	jq -r '.[]|"\(.symbol)=\(.id)=\(.name)"' <<< "${FCLISTS}" | column -s'=' -et -N'SYMBOL,ID,NAME'
	
	printf "\nList of supported VS_CURRENCY (fiat and metals)\n"
	jq -r '.[]' <<< "${VSCLISTS}" | tr "[:lower:]" "[:upper:]" | sort | column -c 80
	
	printf '\nCriptos: %s\n' "$(jq -r '.[]' <<< "${FCLISTS}" | wc -l)"
	printf 'Fiats/m: %s\n' "$(jq -r '.[]' <<< "${VSCLISTS}" | wc -l)"
}

# List of from_currencies
# Create temp file only if not yet created
clistf() {
	# Check if there is a list or create one
	if [[ ! -f "${CGKTEMPLIST1}" ]]; then
		# Make Temp files
		CGKTEMPLIST1=$(mktemp /tmp/cgk.list1.XXXXX) || tmperrf
		export CGKTEMPLIST1
		## Trap temp cleaning functions
		trap "rm1f; exit" EXIT SIGINT
		# Retrieve list from CGK
		${YOURAPP} "https://api.coingecko.com/api/v3/coins/list" | jq -r '[.[] | { key: .symbol, value: .id } ] | from_entries' >> "${CGKTEMPLIST1}"
	fi
}

# List of vs_currencies
tolistf() {
	# Check if there is a list or create one
	if [[ ! -f "${CGKTEMPLIST2}" ]]; then
		CGKTEMPLIST2=$(mktemp /tmp/cgk.list2.XXXXX) || tmperrf
		export CGKTEMPLIST2
		## Trap temp cleaning functions
		trap "rm1f; rm2f; exit" EXIT SIGINT
		# Retrieve list from CGK
		${YOURAPP} "https://api.coingecko.com/api/v3/simple/supported_vs_currencies" | jq -r '.[]' >> "${CGKTEMPLIST2}"
	fi
}

# Change currency code to ID in FROM_CURRENCY
# export currency id as GREPID
changevscf() {
	if jq -r keys[] <"${CGKTEMPLIST1}" | grep -qi "^${*}$"; then
		GREPID="$(jq -r ".${*,,}" <"${CGKTEMPLIST1}")"
	fi
}

# Temporary file management functions
rm1f() { rm -f "${CGKTEMPLIST1}"; }
rm2f() { rm -f "${CGKTEMPLIST2}"; }
tmperrf() { printf "Cannot create temp file at /tmp.\n" 1>&2; exit 1;}


# Precious metals in grams?
ozgramf() {	
	# Precious metals - troy ounce to gram
	#CGK does not support Platinum(xpt) and Palladium(xpd)
	if [[ -n "${GRAMOPT}" ]]; then
		if grep -qi -e 'XAU' -e 'XAG' <<<"${1}"; then
			FMET=1
		fi
		if grep -qi -e 'XAU' -e 'XAG' <<<"${2}"; then
			TMET=1
		fi
		if { [[ -n "${FMET}" ]] && [[ -n "${TMET}" ]];} ||
			{ [[ -z "${FMET}" ]] && [[ -z "${TMET}" ]];}; then
			unset TOZ
			unset GRAM
		elif [[ -n "${FMET}" ]] && [[ -z "${TMET}" ]]; then
			GRAM='/'
		elif [[ -z "${FMET}" ]] && [[ -n "${TMET}" ]]; then
			GRAM='*'
		fi
	else
		unset TOZ
		unset GRAM
	fi
}


# Parse options
while getopts ":0123456789bdeghljmp:s:tv" opt; do
	case ${opt} in
		( [0-9] ) #scale, same as '-sNUM'
			SCL="${SCL}${opt}"
			;;
		( b ) ## Activate the Bank currency function
			BANK=1
			;;
		( d ) #single currency dominance
			DOMOPT=1
			MCAP=1
			;;
		( e ) ## List supported Exchanges
			[[ -z "${EXOPT}" ]] && EXOPT=1 || EXOPT=2
			;;
		( g ) # Gram opt
			GRAMOPT=1
			;;
		( h ) # Show Help
			echo -e "${HELP_LINES}"
			exit 0
			;;
		( l ) ## List available currencies
			LOPT=1
			;;
		( j ) # Print JSON
			PJSON=1
			;;
		( m ) ## Make Market Cap Table
			MCAP=1
			;;
		( p ) # Number of pages to retrieve with the Ticker Function
			TPAGES=${OPTARG}
			;;
		( s ) # Scale, Decimal plates
			SCL=${OPTARG}
			;;
		( t ) # Tickers
			TOPT=1
			;;
		( v ) # Version of Script
			head "${0}" | grep -e '# v'
			exit 0
			;;
		( \? )
			printf "Invalid option: -%s\n" "${OPTARG}" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

## Set default scale if no custom scale
if [[ -z ${SCL} ]]; then
	SCL="${SCLDEFAULTS}"
fi

# Test for must have packages
if [[ -z "${YOURAPP}" ]]; then
	if ! command -v jq &>/dev/null; then
		printf "JQ is required.\n" 1>&2
		exit 1
	fi
	if command -v curl &>/dev/null; then
		YOURAPP="curl -s --compressed"
		YOURAPP2="curl -s --compressed --head"
	elif command -v wget &>/dev/null; then
		YOURAPP="wget -qO-"
		YOURAPP2="wget -qO-"
	else
		printf "cURL or Wget is required.\n" 1>&2
		exit 1
	fi
	export YOURAPP YOURAPP2
	
	#request compressed response
	if ! command -v gzip &>/dev/null; then
		printf 'warning: gzip may be required\n' 1>&2
	fi
fi

# Call opt function
if [[ -n "${MCAP}" ]]; then
	mcapf "${@}"
	exit
elif [[ -n "${EXOPT}" ]]; then
	exf
	exit
elif [[ -n "${LOPT}" ]]; then
	listsf
	exit
fi

# Set equation arguments
# If first argument does not have numbers
if ! [[ "${1}" =~ [0-9] ]]; then
	set -- 1 "${@}"
# if AMOUNT is not a valid expression for Bc
elif [[ -z "$(bc -l <<< "${1}" 2>/dev/null)" ]]; then
	printf "Invalid expression in \"AMOUNT\".\n" 1>&2
	exit 1
fi
# For use with ticker option
CODE1="${2}"
CODE2="${3}"
if [[ -z ${2} ]]; then
	set -- "${1}" "${DEFCUR,,}"
fi
if [[ -z ${3} ]]; then
	set -- "${1}" "${2}" "${DEFVSCUR,,}"
fi

## Check FROM currency
# Make sure "XAG Silver" does not get translated to "XAG Xrpalike Gene"
if [[ -n "${BANK}" ]]; then
	clistf
	tolistf
else
	if [[ "${2,,}" = "xag" ]]; then
		printf "Did you mean xrpalike-gene?\n" 1>&2
		exit 1
	fi
	clistf   # Bank opt needs this anyways
	if ! jq -r '.[],keys[]' <"${CGKTEMPLIST1}" | grep -qi "^${2}$"; then
		[[ -z "$TRYBANK$TOPT" ]] && bankf "${@}" && exit 0
		printf "ERR: currency -- %s\n" "${2^^}" 1>&2
		printf "Check symbol/ID and market pair.\n" 1>&2
		exit 1
	fi
	## Check VS_CURRENCY
	if [[ -z "${TOPT}" ]]; then
		tolistf  # Bank opt needs this anyways
		if ! grep -qi "^${3}$" <"${CGKTEMPLIST2}"; then
			printf "ERR: currency -- %s\n" "${3^^}" 1>&2
			printf "Check symbol/ID and market pair.\n" 1>&2
			exit 1
		fi
	fi
	unset GREPID
	# Check if I can get from currency ID
	changevscf "${2}"
	if [[ -n ${GREPID} ]]; then
		set -- "${1}" "${GREPID}" "${3}"
	fi
fi

## Call opt functions
if [[ -n ${TOPT} ]]; then
	tickerf "${@}"
	exit
elif [[ -n "${BANK}" ]]; then
	bankf "${@}"
	exit
fi

## Default option - Cryptocurrency converter
# Precious metals in grams?
ozgramf "${2}" "${3}"
if [[ -n "${CGKRATERAW}" ]]; then
	# Result for Bank function
	bc -l <<< "${1}*$(jq -r '."'${2,,}'"."'${3,,}'"' <<< "${CGKRATERAW}" | sed 's/e/*10^/g')"
else
	# Make equation and print result
	RATE="$(${YOURAPP} "https://api.coingecko.com/api/v3/simple/price?ids=${2,,}&vs_currencies=${3,,}")"
	if [[ -n ${PJSON} ]]; then
		printf "%s\n" "${RATE}"
		exit
	fi
	RATE="$(jq -r '."'${2,,}'"."'${3,,}'"' <<<"${RATE}" | sed 's/e/*10^/g')"
	RESULT="$(bc -l <<< "((${1})*${RATE})${GRAM}${TOZ}")"
	printf "%.${SCL}f\n" "${RESULT}"
fi

