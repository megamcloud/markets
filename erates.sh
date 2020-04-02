#!/bin/bash
#
# erates.sh -- Currency converter Bash wrapper for exchangeratesapi.io API
# v0.1.12  feb/2020  by mountaineerbr

## Some defaults
SCRIPTBASECUR="EUR"
SCLDEFAULTS=8

## Manual and help
## Usage: $ erates.sh [amount] [from currency] [to currency]
HELP_LINES="WARRANTY & LICENSE
 	This programme needs latest versions of Bash, Curl , Gzip and JQ to work
	properly.

	It is licensed under GPLv3 and distributed without support or bug
	corrections.


NAME
 	\033[01;36mErates.sh -- Bash currency converter for exchangeratesapi.io API\033[00m


SYNOPSIS
	erates.sh [-j] [-sNUM] [AMOUNT] [FROM_CURRENCY] [TO_CURRENCY]
	
	erates.sh [-hlv]


DESCRIPTION
	This programme fetches updated currency rates and can convert any amount
	of one supported currency into another. It is a wrapper	for the
	exchangerates.io API.
	
	Exchangerates.io API is a free service for current and historical for-
	eign exchange rates published by the European Central Bank. Check their
	project: <https://github.com/exchangeratesapi/exchangeratesapi>

	33 central bank currencies are supported but precious metals.
 	
	The reference rates are usually updated around 16:00 CET on every work-
	ing day, except on TARGET closing days. They are based on a regular dai-
	ly  concertation  procedure between central banks across Europe, which 
	normally takes place at 14:15 CET.

	Raw data is against the Euro and it will be used as defaults if you do 
	not specify a TO_CURRENCY.

	Bash Calculator uses a dot for decimal separtor.


	Usage examples:
		
		(1) One US Dollar in Brazilian Real:

		$ erates.sh usd brl

		
		(2) One thousand Euro to Japanese yen using math expression
		    in AMOUNT:
		
		$ erates.sh '(3*245.75)+262+.75' eur jpy


		(3) Half a Danish Krone to Chinese Yuan, 3 decimal plates (scale):

		$ erates.sh -s3 0.5 dkk cny


OPTIONS
	 	
		-h 	Show this help.

		-j 	Debug; print JSON.

		-l 	List supported currencies and their rates agains EUR.

		-s 	Set scale (defaults=8).
		
		-v 	Show this programme version."

## Functions
# List all suported currencies and EUR rates?
listf() {
	printf "Rates against EUR.\n"
 	printf "%s\n" "${JSON}" | jq -r '.rates' | tr -d '{}",' | sort | sed -e 's/^[[:space:]]*//g' -e '/^$/d'
	printf "<https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html>\n"
	exit 0
}


## Check for some needed packages
if ! command -v curl &> /dev/null; then
	printf "%s\n" "Package not found: curl." 1>&2
	exit 1
elif ! command -v jq &> /dev/null; then
	printf "%s\n" "Package not found: JQ." 1>&2
	printf "%s\n" "Ref: https://stedolan.github.io/jq/download/" 1>&2
	exit 1
fi
# Check if there is any argument
if ! [[ ${*} =~ [a-zA-Z]+ ]]; then
	printf "Run with -h for help.\n"
	exit
fi
# Check if you are requesting any precious metals.
if grep -qi -e "XAU" -e "XAG" -e "XAP" -e "XPD" -e "gold" -e "silver" <<< "${*}"; then
	printf "exchangerates.io does not support precious metals.\n" 1>&2
	exit 1
fi

# Parse options
while getopts ":lhjs:tv" opt; do
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
	t ) # Print Timestamp with result
		printf "No timestamp for this API; check -h.\n" 1>&2
		;;
	v ) # Version of Script
		head "${0}" | grep -e '# v'
		exit
		;;
	\? )
		printf "Invalid Option: -%s.\n" "$OPTARG" 1>&2
		exit 1
		;;
  esac
done
shift $((OPTIND -1))

## Set default scale if no custom scale
if [[ -z ${SCL} ]]; then
	SCL=${SCLDEFAULTS}
fi
# Set equation arquments
if ! [[ ${1} =~ [0-9] ]]; then
	set -- 1 ${@:1:2}
fi
if [[ -z ${3} ]]; then
	set -- ${@:1:2} "${SCRIPTBASECUR}"
fi

## Get JSON once
JSON="$(curl --compressed -s "https://api.exchangeratesapi.io/latest")"
## Print JSON?
if [[ -n "${PJSON}" ]]; then
	printf "%s\n" "${JSON}"
	exit
fi

# Call opt functions
[[ "${LISTOPT}" ]] && listf

## Default function -- Currency converter
## Check if request is a supported currency:
if ! [[ "${2^^}" = "EUR" ]] && ! jq -r '.rates | keys[]' <<< "${JSON}" | grep -qi "^${2}$"; then
	printf "Not a supported currency at exchangeratesapi.io: %s\n" "${2}" 1>&2
	exit 1
fi
if ! [[ "${3^^}" = "EUR" ]] && ! jq -r '.rates | keys[]' <<< "${JSON}" | grep -qi "^${3}$"; then
	printf "Not a supported currency at exchangeratesapi.io: %s\n" "${3}" 1>&2
	exit 1
fi

## Get currency rates
if [[ ${2^^} = "EUR" ]]; then
	FROMCURRENCY=1
else
	FROMCURRENCY=$(jq ".rates.${2^^}" <<< "${JSON}")
fi
if [[ ${3^^} = "EUR" ]]; then
	TOCURRENCY=1
else
	TOCURRENCY=$(jq ".rates.${3^^}" <<< "${JSON}")
fi

## Make equation and print result
bc -l <<< "scale=${SCL};((${1})*${TOCURRENCY})/${FROMCURRENCY};"

