#!/bin/bash
# v0.4.1  feb/2020  by mountaineer_br

# Check Tether rates
export LC_NUMERIC="en_US.UTF-8"
printf "\nUSDT/USD Rates\n\n"

CLIBJSON=$(curl --compressed -s "https://coinlib.io/api/v1/coin?key=${CLIBAPIKEY}&pref=USD&symbol=USDT")
ENAMES=($(printf "%s\n" "${CLIBJSON}" | jq -r ".markets[0]|.exchanges[]|.name"))
PRICES=($(printf "%s\n" "${CLIBJSON}" | jq -r ".markets[0]|.exchanges[]|.price"))

CLIBAVG=0
printf "CLIB:\n"
for i in {0..5}; do
	if [[ -n "${PRICES[$i]}" ]]; then
		printf "%s\t%.6f\n" "${ENAMES[$i]}" "${PRICES[$i]}"
		CLIBAVG=$(printf "%s+%s\n" "${CLIBAVG}" "${PRICES[$i]}" | bc -l)
	fi
done

CMCUSDT=$(~/bin/markets/cmc.sh -s8 usdt usd)
printf "CMC:\t%.6f\n" "${CMCUSDT}"
CGKUSDT=$(~/bin/markets/cgk.sh -s8 usdt usd 2>/dev/null)
printf "CGK:\t%.6f\n" "${CGKUSDT}"
printf "\nAvg:\t%.6f\n\n" "$(printf "scale=8;(%s+%s+%s)/5\n" "${CLIBAVG}" "${CMCUSDT}" "${CGKUSDT}" | bc -l)"


