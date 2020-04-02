#!/bin/bash
# cmc.sh -- coinmarketcap.com api access
# v0.9.15  mar/2020  by mountaineerbr

#cmc api personal key
#CMCAPIKEY=''

#defaults
#default from crypto currency
DEFCUR=BTC

#default vs currency
DEFTOCUR=USD

#scale if no custom scale
SCLDEFAULTS=16

#you should not change these:
export LC_NUMERIC='en_US.UTF-8'

#troy ounce to gram ratio
TOZ='31.1034768' 

#manual and help
#usage: $ cmc.sh [amount] [from currency] [to currency]
HELP_LINES="NAME
	Cmc.sh -- Currency Converter and Market Information
		  Coinmarketcap.com API Access


SYNOPSIS
	cmc.sh -b [-gp] [-sNUM] [AMOUNT] 'FROM_CURRENCY' [TO_CURRENCY]
	cmc.sh -m [TO_CURRENCY]
	cmc.sh [-adhlv]


DESCRIPTION
	This programme fetches updated currency rates from <coinmarketcap.com>.
	It can convert any amount of one supported crypto currency into another.
	CMC also converts crypto to ~93 central bank currencies, gold and silver.

	An api key for this script to work is required since the public api has 
	been deactivated.

	You can see a list of supported currencies running the script with the
	argument '-l'. 

	Use option \"-g\" to convert precious metal rates using grams instead of 
	troy ounces for precious metals (${TOZ}grams/troyounce).

	Central bank currency conversions are not supported officially by CMC,
	but we can derive bank currency rates undirectly.

	Default precision is ${SCLDEFAULTS} and can be adjusted with '-s'. Rates should
	be refreshed once per minute by the server.


API KEY
	Please take a little time to register at <https://coinmarketcap.com/api/>
	for a free API key and add it to the 'CMCAPIKEY' variable in the script 
	source code or set it as an environment variable.


WARRANTY
	Licensed under the GNU Public License v3 or better. It is distributed 
	without support or bug corrections. This programme needs Bash, cURL, JQ
	and Coreutils to work properly.

	It is _not_ advisable to depend solely on <coinmarketcap.com> rates for 
	serious	trading. Do your own research!
	
	If you found this script useful, please consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


USAGE EXAMPLES		
		(1)     One Bitcoin in US Dollar:
			
			$ cmc.sh btc
			
			$ cmc.sh 1 btc usd


		(2)     One Dash in ZCash, with 4 decimal plates:
			
			$ cmc.sh -4 dash zec 
			
			$ cmc.sh -s4 dash zec 


		(3)     One thousand Brazilian Real in US Dollar with 3 decimal
			plates:
			
			$ cmc.sh -3b '101+(2*24.5)+850' brl usd



		(4)    One gram of gold in US Dollars:
					
			$ cmc.sh -g xau usd 



		(5) 	Market Ticker in JPY

			$ cmc.sh -m jpy


OPTIONS
		-NUM 	Shortcut for scale setting, same as '-sNUM'.

		-a 	  API key status.

		-b 	  Bank currency function, converts between bank curren-
			  cies and precious metals; automatically set when need-
			  ed; script runs faster when used with non sup ported
			  markets.

		-d 	  Print dominance stats.

		-g 	  Use grams instead of troy ounces; only for precious
			  metals.
		
		-h 	  Show this help.

		-j 	  Debugging, print JSON.

		-l 	  List supported currencies.

		-m [TO_CURRENCY]
			  Market ticker.

		-s [NUM]  Set scale (decimal plates) for some opts; defaults=${SCLDEFAULTS}.

		-p 	  Print timestamp, if available.
		
		-v 	  Script version."

METALS="3575=XAU=Gold Troy Ounce
3574=XAG=Silver Troy Ounce
3577=XPT=Platinum Ounce
3576=XPD=Palladium Ounce"

FIATCODES=(USD AUD BRL CAD CHF CLP CNY CZK DKK EUR GBP HKD HUF IDR ILS INR JPY KRW MXN MYR NOK NZD PHP PKR PLN RUB SEK SGD THB TRY TWD ZAR AED BGN HRK MUR RON ISK NGN COP ARS PEN VND UAH BOB ALL AMD AZN BAM BDT BHD BMD BYN CRC CUP DOP DZD EGP GEL GHS GTQ HNL IQD IRR JMD JOD KES KGS KHR KWD KZT LBP LKR MAD MDL MKD MMK MNT NAD NIO NPR OMR PAB QAR RSD SAR SSP TND TTD UGX UYU UZS VES XAU XAG XPD XPT)

#check for error response
errf() {
	RESP="$(jq -r '.status|.error_code?' <<<"${*}" 2>/dev/null)"

	if { [[ -n "${RESP}" ]] && ((RESP>0)) 2>/dev/null;} || grep -qiE -e 'have been (rate limited|black|banned)' -e 'has banned you' -e 'are being rate limited' <<<"${*}"; then
		{ jq -r '.status.error_message' <<<"${*}" 2>/dev/null || printf 'Err: run script with -j to check server response\n';} 1>&2 

		#print json?
		if [[ -n ${PJSON} ]]; then
			printf '%s\n' "${*}"
			exit 0
		fi

		exit 1
	fi
}

#check currencies
checkcurf() {
	#get data if empty
	if [[ -z "${SYMBOLLIST}" ]]; then
		SYMBOLLIST="$(curl -s --compressed -H "X-CMC_PRO_API_KEY: ${CMCAPIKEY}" -H 'Accept: application/json' -G 'https://pro-api.coinmarketcap.com/v1/cryptocurrency/map')"

		#check error response
		errf "${SYMBOLLIST}"
		
		SYMBOLLIST="$(jq '[.data[]| {"key": .slug, "value": .symbol},{"key": (.name|ascii_upcase), "value": .symbol}] | from_entries' <<<"${SYMBOLLIST}")"
		export SYMBOLLIST
	fi
	
	if [[ -z "${FIATLIST}" ]]; then
		FIATLIST="$(curl -s --compressed -H "X-CMC_PRO_API_KEY: ${CMCAPIKEY}" -H "Accept: application/json" -d "" -G 'https://pro-api.coinmarketcap.com/v1/fiat/map')"

		#check error response
		errf "${FIATLIST}"

		FIATLIST="$(jq -r '.data[].symbol' <<<"${FIATLIST}")"
		FIATLIST+="$(printf '\n%s\n' "${FIATCODES[@]}")"
		export FIATLIST
	fi

	#check from_currency
	if [[ -n "${2}" ]] && ! jq -r '.[]' <<< "${SYMBOLLIST}" | grep -iqx "${2}"; then
		if jq -er '.["'"${2^^}"'"]' <<< "${SYMBOLLIST}" &>/dev/null; then
			set -- "${1}" "$(jq -r '.["'"${2^^}"'"]' <<< "${SYMBOLLIST}")" "${3}"
		else
			[[ -z "$TRYBANK$TOPT$MCAP" ]] && bankf "${@}" && exit 0
			printf 'Err: currency -- %s\n' "${2^^}" 1>&2
			exit 1
		fi
	fi

	#check to_currency
	if [[ -n "${3}" ]]; then
		#reinvert lists for no api key and single ticker opts..
		[[ -z "${CMCAPIKEY}" ]] && SYMBOLLIST="$(jq -r '[keys_unsorted[] as $k | {"key": .[$k], "value": $k}] | from_entries' <<<"${SYMBOLLIST}")"
		
		#check
		if ! grep -qix "${3}" <<< "${FIATLIST}" && ! jq -r '.[]' <<< "${SYMBOLLIST}" | grep -iqx "${3}"; then
			if jq -er '.["'"${3^^}"'"]' <<< "${SYMBOLLIST}" &>/dev/null; then
				set -- "${1}" "${2}" "$(jq -r '.["'"${3^^}"'"]' <<< "${SYMBOLLIST}")"
			else
				printf 'Err: currency -- %s\n' "${3^^}" 1>&2
				exit 1
			fi
		fi
	fi

	#export new args
	ARGS=(${@})
}

#-b bank currency rate function
bankf() {
	unset BANK
	TRYBANK=1
	if [[ -n "${PJSON}" ]] && [[ -n "${BANK}" ]]; then
		#print json?
		printf 'No specific JSON for the bank currency function.\n' 1>&2
		exit 1
	fi

	#rerun script, get rates and process data	
	BTCBANK="$("${BASH_SOURCE[0]}" -p BTC "${2^^}")" || exit 1
	BTCBANKHEAD=$(head -n1 <<< "${BTCBANK}") # Timestamp
	BTCBANKTAIL=$(tail -n1 <<< "${BTCBANK}") # Rate
	
	BTCTOCUR="$("${BASH_SOURCE[0]}" -p BTC "${3^^}")" || exit 1
	BTCTOCURHEAD=$(head -n1 <<< "${BTCTOCUR}") # Timestamp
	BTCTOCURTAIL=$(tail -n1 <<< "${BTCTOCUR}") # Rate
	
	#print timestamp?
	if [[ -n "${TIMEST}" ]]; then
		printf '%s (from currency)\n' "${BTCBANKHEAD}"
		printf '%s ( to  currency)\n' "${BTCTOCURHEAD}"
	fi

	#precious metals in grams?
	ozgramf "${2}" "${3}"

	#calculate result & print result 
	RESULT="$(bc -l <<< "(((${1})*${BTCTOCURTAIL})/${BTCBANKTAIL})${GRAM}${TOZ}")"
	
	#check for errors
	if [[ -z "${RESULT}" ]]; then
		#printf 'Err: invalid currency code(s)\n' 1>&2
		exit 1
	else
		printf "%.${SCL}f\n" "${RESULT}"
	fi
}

#market capital function
mcapf() {
	#check for input to_currency
	if [[ "${1^^}" =~ ^(USD|BRL|CAD|CNY|EUR|GBP|JPY|BTC|ETH|XRP|LTC|EOS|USDT)$ ]]; then
		true	
	elif [[ -n "${DOMOPT}" ]] || [[ -z "${1}" ]]; then
		set -- USD
	elif [[ -n "${1}" ]]; then
		#check to_currency (convert prices)
		checkcurf '' '' "${1}" && set -- "${ARGS[@]}"
	fi

	#get market data
	CMCGLOBAL=$(curl -s --compressed -H "X-CMC_PRO_API_KEY:  ${CMCAPIKEY}" -H 'Accept: application/json' -d "convert=${1^^}" -G 'https://pro-api.coinmarketcap.com/v1/global-metrics/quotes/latest')
	
	#print json?
	if [[ -n ${PJSON} ]]; then
		printf '%s\n' "${CMCGLOBAL}"
		exit 0
	fi

	#check error response
	errf "${CMCGLOBAL}"

	#-d dominance opt
	if [[ -n "${DOMOPT}" ]]; then
		printf "BTC: %'.2f %%\n" "$(jq -r '.data.btc_dominance' <<< "${CMCGLOBAL}")"
		printf "ETH: %'.2f %%\n" "$(jq -r '.data.eth_dominance' <<< "${CMCGLOBAL}")"
		exit 0
	fi

	#timestamp
	LASTUP=$(jq -r '.data.last_updated' <<< "${CMCGLOBAL}")
	
	#avoid erros being printed
	{
	printf '## CRYPTO MARKET INFORMATION\n'
	date --date "${LASTUP}"  '+#  %FT%T%Z'
	printf '\n# Exchanges     : %s\n' "$(jq -r '.data.active_exchanges' <<< "${CMCGLOBAL}")"
	printf '# Active cryptos: %s\n' "$(jq -r '.data.active_cryptocurrencies' <<< "${CMCGLOBAL}")"
	printf '# Market pairs  : %s\n' "$(jq -r '.data.active_market_pairs' <<< "${CMCGLOBAL}")"

	printf '\n## All Crypto Market Cap\n'
	printf "   %'.2f %s\n" "$(jq -r ".data.quote.${1^^}.total_market_cap" <<< "${CMCGLOBAL}")" "${1^^}"
	printf ' # Last 24h Volume\n'
	printf "    %'.2f %s\n" "$(jq -r ".data.quote.${1^^}.total_volume_24h" <<< "${CMCGLOBAL}")" "${1^^}"
	printf ' # Last 24h Reported Volume\n'
	printf "    %'.2f %s\n" "$(jq -r ".data.quote.${1^^}.total_volume_24h_reported" <<< "${CMCGLOBAL}")" "${1^^}"
	
	printf '\n## Bitcoin Market Cap\n'
	printf "   %'.2f %s\n" "$(jq -r "(.data.quote.${1^^}.total_market_cap-.data.quote.${1^^}.altcoin_market_cap)" <<< "${CMCGLOBAL}")" "${1^^}"
	printf ' # Last 24h Volume\n'
	printf "    %'.2f %s\n" "$(jq -r "(.data.quote.${1^^}.total_volume_24h-.data.quote.${1^^}.altcoin_volume_24h)" <<< "${CMCGLOBAL}")" "${1^^}"
	printf ' # Last 24h Reported Volume\n'
	printf "    %'.2f %s\n" "$(jq -r "(.data.quote.${1^^}.total_volume_24h_reported-.data.quote.${1^^}.altcoin_volume_24h_reported)" <<< "${CMCGLOBAL}")" "${1^^}"
	printf '## Circulating Supply\n'
	printf " # BTC: %'.2f bitcoins\n" "$(bc -l <<< "$(curl -s --compressed "https://blockchain.info/q/totalbc")/100000000")"

	printf '\n## AltCoin Market Cap\n'
	printf "   %'.2f %s\n" "$(jq -r ".data.quote.${1^^}.altcoin_market_cap" <<< "${CMCGLOBAL}")" "${1^^}"
	printf ' # Last 24h Volume\n'
	printf "    %'.2f %s\n" "$(jq -r ".data.quote.${1^^}.altcoin_volume_24h" <<< "${CMCGLOBAL}")" "${1^^}"
	printf ' # Last 24h Reported Volume\n'
	printf "    %'.2f %s\n" "$(jq -r ".data.quote.${1^^}.altcoin_volume_24h_reported" <<< "${CMCGLOBAL}")" "${1^^}"
	
	printf '\n## Dominance\n'
	printf " # BTC: %'.2f %%\n" "$(jq -r '.data.btc_dominance' <<< "${CMCGLOBAL}")"
	printf " # ETH: %'.2f %%\n" "$(jq -r '.data.eth_dominance' <<< "${CMCGLOBAL}")"

	printf '\n## Market Cap per Coin\n'
	printf " # Bitcoin : %'.2f %s\n" "$(jq -r "((.data.btc_dominance/100)*.data.quote.${1^^}.total_market_cap)" <<< "${CMCGLOBAL}")" "${1^^}"
	printf " # Ethereum: %'.2f %s\n" "$(jq -r "((.data.eth_dominance/100)*.data.quote.${1^^}.total_market_cap)" <<< "${CMCGLOBAL}")" "${1^^}"
	#avoid erros being printed
	} 2>/dev/null
}

#-l print currency lists
listsf() {
	#get data
	PAGE="$(curl -s --compressed -H "X-CMC_PRO_API_KEY: ${CMCAPIKEY}" -H 'Accept: application/json' -G 'https://pro-api.coinmarketcap.com/v1/cryptocurrency/map')"
	
	#print json?
	if [[ -n ${PJSON} ]]; then
		printf '%s\n' "${PAGE}"
		exit 0
	fi
	
	#check error response
	errf "${PAGE}"
	
	#make table
	printf 'CRYPTOCURRENCIES\n'		
	LIST="$(jq -r '.data[] | "\(.id)=\(.symbol)=\(.name)"' <<<"${PAGE}")"
	column -s'=' -et -N 'ID,SYMBOL,NAME' <<<"${LIST}"
	
	printf '\nBANK CURRENCIES\n'
	LIST2="$(curl -s --compressed -H "X-CMC_PRO_API_KEY: ${CMCAPIKEY}" -H "Accept: application/json" -d "" -G https://pro-api.coinmarketcap.com/v1/fiat/map | jq -r '.data[]|"\(.id)=\(.symbol)=\(.sign)=\(.name)"')"
	column -s'=' -et -N'ID,SYMBOL,SIGN,NAME' <<<"${LIST2}"
	column -s'=' -et -N'ID,SYMBOL,NAME' <<<"${METALS}"

	printf 'Cryptos: %s\n' "$(wc -l <<<"${LIST}")"
	printf 'BankCur: %s\n' "$(wc -l <<<"${LIST2}")"
	printf 'Metals : %s\n' "$(wc -l <<<"${METALS}")"
	exit
}

#-a api status
apif() {
	PAGE="$(curl -s --compressed -H "X-CMC_PRO_API_KEY: ${CMCAPIKEY}" -H 'Accept: application/json'  'https://pro-api.coinmarketcap.com/v1/key/info')"

	#print json?
	if [[ -n ${PJSON} ]]; then
		printf '%s\n' "${PAGE}"
		exit 0
	fi
	
	#check error response
	errf "${PAGE}"
		
	#print heading and status page
	printf 'API key: %s\n\n' "${CMCAPIKEY}"
	tr -d '{}",' <<<"${PAGE}"| sed -e 's/^\s*\(.*\)/\1/' -e '1,/data/d' -e 's/_/ /g'| sed -e '/^$/N;/^\n$/D' | sed -e 's/^\([a-z]\)/\u\1/g'
}

#precious metals in grams?
ozgramf() {
	#precious metals - ounce to gram
	if [[ -n "${GRAMOPT}" ]]; then
		if grep -qi -e 'XAU' -e 'XAG' -e 'XPT' -e 'XPD' <<<"${1}"; then
			FMET=1
		fi
		if grep -qi -e 'XAU' -e 'XAG' -e 'XPT' -e 'XPD' <<<"${2}"; then
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


#parse options
while getopts ':0123456789abdlmghjs:vp' opt; do
	case ${opt} in
		( [0-9] ) #scale, same as '-sNUM'
			SCL="${SCL}${opt}"
			;;
		( a ) #api key status
			APIOPT=1
			;;
		( b ) #hack central bank currency rates
			BANK=1
			;;
		( d ) #dominance only opt
			DOMOPT=1
			MCAP=1
			;;
		( g ) #gram opt
			GRAMOPT=1
			;;
		( j ) #debug: print json
			PJSON=1
			;;
		( l ) #list available currencies
			LISTS=1
			;;
		( m ) #market capital function
			MCAP=1
			;;
		( h ) #show help
			echo -e "${HELP_LINES}"
			exit 0
			;;
		( p ) #print timestamp with result
			TIMEST=1
			;;
		( s ) #decimal plates
			SCL="${OPTARG}"
			;;
		( v ) #script version
			grep -m1 '# v' "${0}"
			exit 0
			;;
		( \? )
			printf 'Invalid option: -%s\n' "$OPTARG" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

#api key test
if [[ -z "${CMCAPIKEY}" ]]; then
	printf 'A free api key is needed.\n' 1>&2
	exit 1
#test for must have packages
elif [[ -z "${CCHECK}" ]]; then
	if ! command -v jq &>/dev/null; then
		printf 'JQ is required.\n' 1>&2
		exit 1
	fi
	if ! command -v curl &>/dev/null; then
		printf 'cURL is required.\n' 1>&2
		exit 1
	fi
	CCHECK=1
	export CCHECK
fi

#set custom scale
[[ -z ${SCL} ]] && SCL="${SCLDEFAULTS}"

#call opt functions
if [[ -n "${MCAP}" ]]; then
	mcapf "${@}"
	exit
elif [[ -n "${LISTS}" ]]; then
	listsf
elif [[ -n "${APIOPT}" ]]; then
	apif
	exit
fi

#set equation arguments
#if first argument does not have numbers
if ! [[ "${1}" =~ [0-9] ]]; then
	set -- 1 "${@}"
#if amount is not a valid expression for bc
elif [[ -z "$(bc -l <<< "${1}" 2>/dev/null)" ]]; then
	printf 'Err: invalid expression in AMOUNT\n' 1>&2
	exit 1
fi
if [[ -z ${2} ]]; then
	set -- "${1}" ${DEFCUR^^}
fi
if [[ -z ${3} ]]; then
	set -- "${1}" "${2}" ${DEFTOCUR^^}
fi

#check currencies
[[ -z "${BANK}" ]] && checkcurf "${@}" && set -- "${ARGS[@]}"

#call opt functions
if [[ -n "${BANK}" ]]; then
	bankf "${@}"
#default function
#currency converter
else
	#get rate json
	CMCJSON=$(curl -s --compressed -H "X-CMC_PRO_API_KEY: ${CMCAPIKEY}" -H 'Accept: application/json' -d "&symbol=${2^^}&convert=${3^^}" -G 'https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest')
	
	#print json?
	if [[ -n ${PJSON} ]]; then
		printf '%s\n' "${CMCJSON}"
		exit 0
	fi
		
	#check error response
	errf "${CMCJSON}"
		
	#get pair rate
	CMCRATE=$(jq -r ".data[] | .quote.${3^^}.price" <<< "${CMCJSON}" | sed 's/e/*10^/g') 
	
	#print json timestamp ?
	if [[ -n ${TIMEST} ]]; then
		JSONTIME=$(jq -r ".data.${2^^}.quote.${3^^}.last_updated" <<< "${CMCJSON}")
		date --date "$JSONTIME" '+#%FT%T%Z'
	fi
	
	#make equation and calculate result
	#metals in grams?
	ozgramf "${2}" "${3}"
	
	RESULT="$(bc -l <<< "((${1})*${CMCRATE})${GRAM}${TOZ}")"
	
	printf "%.${SCL}f\n" "${RESULT}"
fi

