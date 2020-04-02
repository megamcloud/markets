#!/bin/bash
# myc.sh - Currency converter, API access to MyCurrency.com
# v0.3.2  feb/2020  by mountaineerbr

## Defaults
# Scale (decimal plates):
SCLDEFAULTS=6

#Don't change this:
export LC_NUMERIC="en_US.UTF-8"

## Manual and help
## Usage: $ myc.sh [amount] [from currency] [to currency]
HELP_LINES="NAME
	Myc.sh -- Currency converter
	       -- Bash interface for <MyCurrency.com> free API
	       -- 免費版匯率API接口


SYNOPSIS
	myc.sh [-hlv]

	myc.sh [-sNUM] [AMOUNT] [FROM_CURRENCY] [TO_CURRENCY]


DESCRIPTION
	Myc.sh fetches central bank currency rates from <mycurrency.net> and can
	convert any amount of one supported currency into another. It supports 
	163 currency rates at the moment. Precious metals and cryptocurrency 
	rates are not supported.	
	
	AMOUNT can be a floating point number or a math expression that is un-
	derstandable by Bash Bc.

	Rates are updated every hour.


WARRANTY
	Licensed under the GNU Public License v3 or better and is distributed 
	without support or bug corrections.

	Required packages: bash, jq, curl or wget and gzip.

	If you found this script useful, consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr


USAGE EXAMPLES
	(1) One Brazilian real in US Dollar:

		$ myc.sh brl

		$ myc.sh 1 brl usd

		
	(2) One thousand US Dollars in Japanese Yen:
		
		$ myc.sh 100 usd jpy
		

		Using math expression in AMOUNT:
		
		$ myc.sh '101+(2*24.5)+850' usd jpy


	(3) Half a Danish Krone in Chinese Yuan with 3 decimal 
	    plates (scale):

		$ myc.sh -s3 0.5 dkk cny


OPTIONS
	-h 	Show this help.

	-j 	Debug, print JSON.
	
	-l 	List supported currencies, if no symbol is given, rates
	   	against USD.
	
	-s NUM 	Scale (decimal plates), defaults=${SCLDEFAULTS}.
	
	-v 	Print this script version.
	"

# Check if there is any argument
if [[ -z "${@}" ]]; then
	printf "Run with -h for help.\n"
	exit 1
fi
# Check if you are requesting any precious metals.
if grep -qi -e "XAU" -e "XAG" -e "XAP" -e "XPD" <<< "${*}"; then
	printf "Mycurrency.com does not support precious metals.\n" 1>&2
	exit 1
fi

# Parse options
while getopts ":lhjs:v" opt; do
  case ${opt} in
  	l ) ## List available currencies
		LISTOPT=1
		;;
	h ) # Show Help
		echo -e "${HELP_LINES}"
		exit 0
		;;
	j ) # Print JSON
		PJSON=1
		;;
	s ) # Decimal plates
		SCL=${OPTARG}
		;;
	v ) # Version of Script
		head "${0}" | grep -e '# v'
		exit
		;;
	\? )
		printf "Invalid option: -%s.\n" "$OPTARG" 1>&2
		exit 1
		;;
  esac
done
shift $((OPTIND -1))

#Check for JQ
if ! command -v jq &>/dev/null; then
	printf "JQ is required.\n" 1>&2
	exit 1
fi

# Test if cURL or Wget is available
if command -v curl &>/dev/null; then
	YOURAPP='curl -sL --compressed'
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


## Set default scale if no custom scale
test -z "${SCL}" && SCL="${SCLDEFAULTS}"

# Set equation arquments
if ! [[ ${1} =~ [0-9] ]]; then
	set -- 1 ${@:1:2}
fi

if [[ -z ${3} ]]; then
	set -- ${@:1:2} "USD"
fi

## Get JSON once
JSON="$(${YOURAPP} "https://www.mycurrency.net/US.json")"

## Print JSON?
if [[ -n "${PJSON}" ]]; then
	printf "%s\n" "${JSON}"
	exit
fi
## List all suported currencies and USD rates?
if [[ -n ${LISTOPT} ]]; then

	# Test screen width
	# If stdout is open, trim some wide columns
	if [[ -t 1 ]]; then
		COLCONF="-TCOUNTRY,CURRENCY"
	fi

	printf "Supported currencies against USD.\n"
	jq -r '.rates[]|"\(.currency_code)=\(.rate)=\(.name) (\(.code|ascii_downcase))=\(.currency_name)=\(.hits)"' <<< "${JSON}" |
		column -et -s'=' -N'SYMBOL,RATE,COUNTRY,CURRENCY,WEBHITS' ${COLCONF}
	printf "Currencies: %s\n" "$(jq -r '.rates[].currency_code' <<< "${JSON}" | wc -l)"
	exit
fi

#check that symbols are supported
if ! jq -r '.rates[].currency_code'<<<"${JSON}" | grep -q "^${2^^}$"; then 
	printf 'Error: unsupported symbol -- %s\n' "${2^^}" 
	exit 1
elif ! jq -r '.rates[].currency_code'<<<"${JSON}" | grep -q "^${3^^}$"; then 
	printf 'Error: unsupported symbol -- %s\n' "${3^^}" 
	exit 1
fi

## Grep currency data and rates
CJSON=$(jq '[.rates[] | { key: .currency_code, value: .rate } ] | from_entries' <<< "${JSON}")

## Get currency rates
FROMCURRENCY=$(jq ".${2^^}" <<< "${CJSON}")
TOCURRENCY=$(jq ".${3^^}" <<< "${CJSON}")

## Make equation and print result
bc -l <<< "scale=${SCL};((${1})*${TOCURRENCY})/${FROMCURRENCY}"

exit

#Dead code

