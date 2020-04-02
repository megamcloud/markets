#!/bin/bash
# Foxbit.sh -- Pegar taxas de criptos pelo API da FoxBit
# v0.2.44  06/dez/2019  by mountaineer_br

## Defaults
#Mercado padrão 
ID=1; IDNAME=BTC
#Intervalo de estatísticas do ticker
INTV=86400  #equivalente a 24h
#INTV=21600 #equivalente a 6h
#Manter-se conectado? Comente para puxar 
#somente uma vez e parar (igual opção -q) 
ROLAR='-n'

HELP="GARANTIA
	Este programa/script é software livre e está licenciado sob a Licença 
	Geral Pública v3 ou superior do GNU. Sua distribuição não oferece supor-
	te nem correção de bugs.

	O script precisa do Bash ou Z-shell, JQ e Websocat.


SINOPSE
	foxbit.sh [-pq] [-i \"NUM\"] [CÓDIGO_CRIPTOMOEDA]	

	foxbit.sh [-hv]


 	O Foxbit.sh pega as cotações de criptomoedas diretamente da API da 
	FoxBit. Como o acesso é através de um Websocket, a conexão fica aberta 
	e quando houver alguma atualização por parte do servidor, ele nos man-
	dará pelo canal de comunicação já aberto.

	A opção padrão gera um ticker com estatísticas do último período de tem-
	po (6 horas), ou seja o ticker sempre tem as estatísticas das últimas 
	negociações que ocorreram nessa última janela de tempo, e o preço mais 
	atualizado. OBS: o preço mais recente é o do Fechamento.

	Se nenhum parâmetro for especificado, BTC é usado. Para ver o ticket de
	outras moedas, especificar o nome da moeda no primeiro argumento.

	Percebi nos testes que algumas vezes o API da FoxBit nem responde. Nesse
	caso, basta reiniciar o script.

	Os tickeres que a FoxBit oferece são:
	
		BTC 		LTC
		ETH		TUSD
		XRP
	

	O intervalo de tempo dos tickeres pode ser mudado. O padrão é de 24 ho-
	ras (24h). Os intervalos suportados são somente os seguintes:

		Intervalos 	Equivalente em segundos
		 1m		   60 	
		30m		 1800 	
	 	 1h  		 3600 	
	 	 6h  		21600 	
		12h  		43200 	
		24h  		86400 	

	
	O spread (Spd) e a variação (Var) são calculados a partir das seguintes
	fórmulas:

		[ Alta - Baixa ]
	
		[ Venda - Compra ]
	
		[ Fechamento - Abertura ]


LIMITES
	Segundo os documentos de API:

		\"rate limit: 500 requisições à cada 5 min\"

		<https://foxbit.com.br/api/>


EXEMPLOS DE USO

		Ticker rolante do Ethereum:

		$ foxbit.sh ETH


		Ticker rolante da Litecoin das últimas 6 horas:

		$ foxbit.sh -i 6h LTC

		
		Somente as atualizações de preço do Bitcoin:

		$ foxbit.sh -p
		
		$ foxbit.sh -p BTC


OPÇÕES
	-i 	Intervalo de tempo do ticker; válidos:  1m, 30m, 1h,
		6h, 12h, 24h; padrão=24h.

	-h 	Mostra esta Ajuda.
	
	-p 	Preço somente.

	-q 	Puxar dados uma vez e sair.

	-v 	Mostra a versão deste script."



# Test if JQ and Websocat are available
if ! command -v websocat &>/dev/null; then
	printf "Websocat é requerido.\n" 1>&2
	exit 1
elif ! command -v jq &>/dev/null; then
	printf "JQ é requerido.\n" 1>&2
	exit 1
fi

# Functions
## Price of Instrument
statsf () {
	websocat ${ROLAR} -t --ping-interval 20 "wss://apifoxbitprodlb.alphapoint.com/WSGateway" <<< '{"m":0,"i":4,"n":"SubscribeTicker","o":"{\"OMSId\":1,\"InstrumentId\":'${ID}',\"Interval\":'${INTV}',\"IncludeLastCount\":1}"}' | jq --unbuffered -r '.o' |
		jq --unbuffered -r --arg IDNA "${IDNAME}" '.[] |"",
			"## Foxbit Ticker Rolante",
			"Intervl: \((.[0]-.[9])/1000) secs (\((.[0]-.[9])/3600000) h)",
			"Inicial: \((.[9]/1000) | strflocaltime("%Y-%m-%dT%H:%M:%S%Z"))",
			"Final__: \((.[0]/1000) | strflocaltime("%Y-%m-%dT%H:%M:%S%Z"))",
			"InstrID: \(.[8]) (\($IDNA))",
			"Volume_: \(.[5])",
			"Alta___: \(.[1])",
			"Baixa__: \(.[2])   \tVar: \((.[1]-.[2])|round)",
			"Venda__: \(.[7])",
			"Compra_: \(.[6])   \tSpd: \((.[7]-.[6])|round)",
			"#Abert_: \(.[3])",
			"*Fecham: \(.[4])   \tVar: \((.[4]-.[3])|round)"'
}
#https://www.fool.com/knowledge-center/how-to-calculate-the-bid-ask-spread-percentage.aspx
#https://www.fool.com/knowledge-center/how-to-calculate-spread.aspx
#https://www.calculatorsoup.com/calculators/financial/bid-ask-calculator.php

## Only Price of Instrument
pricef () {
	websocat ${ROLAR} -t --ping-interval 20 "wss://apifoxbitprodlb.alphapoint.com/WSGateway" <<< '{"m":0,"i":4,"n":"SubscribeTicker","o":"{\"OMSId\":1,\"InstrumentId\":'${ID}',\"Interval\":60,\"IncludeLastCount\":1}"}' | jq --unbuffered -r '.o' | jq --unbuffered -r '.[]|.[4]'
}

# Parse options
while getopts ":hvi:pq" opt; do
	case ${opt} in
		i ) # Interval
			INTV="${OPTARG}"
			case ${OPTARG} in
				( 1m|1min )
					INTV=60
					;;
				( 30m|30min )
					INTV=1800
					;;
				( 1h|1hora )
					INTV=3600
					;;
				( 6h|6horas )
					INTV=21600
					;;
				( 12h|12horas )
					INTV=43200
					;;
				( 24h|24horas )
					INTV=86400
					;;
			esac
			if ! grep -q -e "^60$" -e "^1800$" -e "^3600$" -e "^21600$" -e "^43200$" -e "^86400$" <<<"${INTV}"; then
				printf "Intervalo não suportado!\n" 1>&2
				INTV=86400
			fi
			;;
		( h ) # Help
			head "${0}" | grep -e '# v'
			echo -e "${HELP}"
			exit 0
			;;
		( q ) # Puxar dados uma vez e sair
			unset ROLAR
			;;
		( p ) # Preço somente
			POPT=1
			;;
		( v ) # Version of Script
			head "${0}" | grep -e '# v'
			exit 0
			;;
		( \? )
			printf "Invalid option: -%s\n" "$OPTARG" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

# Get Product ID
if [[ -n "${1}" ]]; then
	case "${1^^}" in
		( BTC|BITCOIN )
			ID=1
			IDNAME=BTC
			;;
		( LTC|LITECOIN )
			ID=2
			IDNAME=LTC
			;;
		( ETH|ETHER|ETHEREUM )
			ID=4
			IDNAME=ETH
			;;
		( TUSD|TRUEUSD )
			ID=6
			IDNAME=TUSD
			;;
		( XRP|RIPPLE )
			ID=10
			IDNAME=XRP
			;;
		( * )
			printf "Shitcoin indisponível: %s.\n" "${1^^}" 1>&2
			exit 1
			;;
	esac
fi

# Trap Interrupt sign INT
trap 'printf "\n"; exit 0;' INT

# Call opt functions
if [[ -n "${POPT}" ]]; then
	pricef
	exit
fi

# Defaul opt
# Ticker rolante, cortar colunas
statsf

exit

# Dead code
:<<!
\t %\(((.[1]-.[2])/.[1])*100)",
\t %\(((.[7]-.[6])/.[7])*100)",
\t %\(((.[4]-.[3])/.[3])*100)"'
| cut -c-${CUTAT}
[
    {
        "EndDateTime": 0, // POSIX format
        "HighPX": 0,
        "LowPX": 0,
        "OpenPX": 0,
        "ClosePX": 0,
        "Volume": 0,
        "Bid": 0,
        "Ask": 0,
        "InstrumentId": 1,
        "BeginDateTime": 0 // POSIX format
    }
]

## Products
productsf() {
websocat "wss://apifoxbitprodlb.alphapoint.com/WSGateway" <<<'{"m":0,"i":10,"n":"GetProducts","o":"{\"OMSId\":1}"}' | jq -r '.o' | jq -r '.'
}
#productsf

Product ID 	Product
1 		BTC
2 		BRL
3 		LTC
4 		ETH
5 		TUSD
6 		XRP
## ?
#websocat "wss://apifoxbitprodlb.alphapoint.com/WSGateway" <<< '{"m":0,"i":12,"n":"GetInstruments","o":"{"OMSId":1}"}' | jq -r '.'
!

