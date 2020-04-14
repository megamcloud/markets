#!/bin/bash
# bcalc.sh -- simple bash bc wrapper
# v0.6.11  apr/2020  by mountaineerbr

#defaults

#use of record file (enabled=1/disabled=0 or unset)
BCREC=1

#special variable that holds last entry in the record file
#HOLD=res
HOLD='(res|ans)'

#record file path
RECFILE="${HOME}/.bcalc_record"

#extension file path
EXTFILE="${HOME}/.bcalc_extensions"

#don't change these

#length of result line (newer bash accepts '0' to disable multiline)
export BC_LINE_LENGTH=1000

#make sure numeric locale is set correctly
export LC_NUMERIC=en_US.UTF-8

#man page
HELP_LINES="NAME
	bcalc.sh -- simple bash bc wrapper


SYNOPSIS
	bcalc.sh  [-cf] [-s'NUM'|-NUM] 'EXPRESSION'
	
	bcalc.sh  -t [-s'NUM'|-NUM] [-f] 'EXPRESSION'

	bcalc.sh  -n 'SHORT NOTE'

	bcalc.sh  [-cchrv]


DESCRIPTION
	Bcalc.sh uses the powerful Bash Calculator (Bc) with its math library
	and adds some useful features described below.

	A record file (a history) is created at '${RECFILE}'
	To disable using a record file set option '-f' or unset BCREC in the 
	script head code, section 'defaults'. If a record file is available, the
	special variable '${HOLD}' can be used in EXPRESSION and holds the last
	entry in the record file. This special variable can be user-defined in
	the script head source code, section defaults.

	If no EXPRESSION is given, wait for for Stdin (from pipe) or user input.
	Press 'Ctr+D' to send the EOF signal, as in Bc. If no user EXPRESSION
	was given so far, prints last entry in the record file.

	EXPRESSIONS containing special chars interpreted by your shell may need
	escaping.

	The number of decimal plates (scale) of output floating point numbers is
	dependent on user input for all operations except division, as in pure
	Bc. Mathlib scale defaults to 20 plus one uncertainty digit and the sci-
	entific extensions defaults to 100. If the scale option '-s' is not set 
	explicitly, trailing zeroes will be trimmed by a special Bc function be-
	fore being printed to screen.

	Remember that the decimal separator must be a dot '.'. Results can be 
	printed with a thousands separator setting option '-t', in which case a
	comma ',' is used as thousands delimiter.


BC MATH LIBRARY
	Bcalc.sh uses Bc with the math library. Useful functions from Bc man:

		The math  library  defines the following functions:

		s (x)  The sine of x, x is in radians.

		c (x)  The cosine of x, x is in radians.

		a (x)  The arctangent of x, arctangent returns radians.

		l (x)  The natural logarithm of x.

		e (x)  The exponential function of raising e to the value x.

		j (n,x)
		       The Bessel function of integer order n of x.


SCIENTIFIC EXTENSION

	The scientific option will try to download a copy of a table of scien-
	tific constants and extra math functions such as 'ln' and 'log'. Once 
	downloaded, it will be kept for future use. Download of extensions re-
	quires Wget or cURL and will be placed at '${EXTFILE}'

	Extensions from:

		<http://x-bc.sourceforge.net/scientific_constants.bc>

		<http://x-bc.sourceforge.net/extensions.bc>


BASH ALIASES
	Consider creating a bash alias. Add to your ~/.bashrc:

		alias c='/path/to/bcalc.sh'


	There are two interesting functions for using pure Bc interactively:

		c() { echo \"\${*}\" | bc -l;}

		alias c=\"bc -l <<<'\"


	In the latter, user must type a  \"'\" sign after the expression to end
	quoting.


WARRANTY
	This programme is distributed without support or bug corrections. Li-
	censed under GPLv3 and above. Made and tested with Bash 5 and the GNU
	suite of core tools.

	If useful, consider giving me a nickle! =)

		bc1qlxm5dfjl58whg6tvtszg5pfna9mn2cr2nulnjr

	  
BUGS
	When option '-t' is used, decimal precision will become limited and de-
	teriorated if the resulting number is longer than 20 digits total. That
	is printf limitation as it uses bc with the mathlib internally.

	Multiline input will skip format settings defined by script options.

	Bash Bc can only use point as decimal separator, independently of user
	locale.


USAGE EXAMPLES
	Below are shown some ways to escaping specials chars to avoid their being
	interpreted by the shell and also some examples of this script options.
	Chars '-' and '()' need escaping when they start the expression, while '*'
	needs escaping every time.

		(I)   Escaping
			$ bcalc.sh '(-20-20)/2'
			
			$ bcalc.sh \\(20+20\\)/2

			$ bcalc.sh -- -3+30

			$ bcalc.sh 'a=4;dog=1;cat=dog; a/(cat+dog)'
		    
		      Z-shell users need extra escaping
			% bcalc.sh '10*10*10'
			
			% bcalc.sh 10\\*10\\*10
		    
			% bcalc.sh '2^2+(30)'
	
			
		(II)  Setting scale and thousands separator
			$ bcalc.sh -s2 1/3
	
			$ bcalc.sh -2 1/3
			
			$ bcalc.sh 'scale=2;1/3'
	
			$ echo '0.333333333' | bcalc.sh -2
				result: 0.33

			$ bcalc.sh -t 100000000
				result: 100,000,000.00


		(III) Scientific extensions
			$ bcalc.sh -c 'ln(0.3)'   #natural log function
	
			$ bcalc.sh -c 0.234*na    #'na' is Avogadro's constant
	

		(IV)  Adding notes
			$ bcalc.sh -n This is my note.
			
			$ bcalc.sh -n '<This; is my w||*ird not& & >'
	

OPTIONS
	-NUM 	Shortcut for scale setting, same as '-sNUM'.

	-c 	Use scientific extensions; pass twice to print extensions.

	-f 	Do not use a record file.

	-h 	Show this help.

	-n 	Add note to last entry in the record file.

	-r 	Print record file.

	-s 	Set scale (decimal plates).

	-t 	Thousands separator.

	-v 	Print this script version."


#functions

#-n add note function
notef() {
	if [[ -n "${*}" ]]; then
		sed -i "$ i\>> ${*}" "${RECFILE}"
		exit 0
	else
		printf 'Note is empty.\n' 1>&2
		exit 1
	fi
}
#https://superuser.com/questions/781558/sed-insert-file-before-last-line
#http://www.yourownlinux.com/2015/04/sed-command-in-linux-append-and-insert-lines-to-file.html

#-c scientific extension function
setcf() {
	#test if extensions file exists, if not download it from the internet
	if ! [[ -f "${EXTFILE}" ]]; then
		#test for cURL or Wget
		if command -v curl &>/dev/null; then
			YOURAPP='curl -L'
		elif command -v wget &>/dev/null; then
			YOURAPP='wget -O-'
		else
			printf 'cURL or Wget is required.\n' 1>&2
			exit 1
		fi
	
		#download extensions
		{ 
		${YOURAPP} 'http://x-bc.sourceforge.net/scientific_constants.bc'
		printf '\n'
		${YOURAPP} 'http://x-bc.sourceforge.net/extensions.bc'
		printf '\n'
		} > "${EXTFILE}"
	fi
	
	#print extension file?
	if [[ "${CIENTIFIC}" -eq 2 ]]; then
		cat "${EXTFILE}"
		exit
	fi
	
	#set extensions for use with Bc
	#scientific extensions defaults scale=100
	EXT="$(<"${EXTFILE}")"
}


#parse options
while getopts ':0123456789cfhnrs:tv' opt; do
	case ${opt} in
		( [0-9] ) #scale, same as '-sNUM'
			SCL="${SCL}${opt}"
			;;
		( c ) #load cientific extensions
		      #twice to print cientific extensions
			[[ -z "${CIENTIFIC}" ]] && CIENTIFIC=1 || CIENTIFIC=2
			;;
		( f ) #no record file
			unset BCREC
			;;
		( h ) #show this help
			printf '%s\n' "${HELP_LINES}"
			exit
			;;
		( n ) #disable record file
			NOTEOPT=1
			;;
		( r ) #print record
			if [[ -f "${RECFILE}" ]]; then
				cat "${RECFILE}"
				exit 0
			else
				printf 'No record file.\n' 1>&2
				exit 1
			fi
			;;
		( s ) #scale (decimal plates)
			SCL="${OPTARG}"
			;;
		( t ) #thousands separator
			TOPT=1
			;;
		( v ) #show this script version
			grep -m1 '^# v' "${0}"
			exit 0
			;;
		( \? )
			printf 'Invalid option: -%s\n' "${OPTARG}" 1>&2
			#check if last arg starts with a negative sign
			[[ "${@: -1}" = -* ]] && printf "First char in EXPRESSION is '-', try escaping: '(%s)'\n" "${@: -1}" 1>&2
			exit 1
			;;
	esac
done
shift $((OPTIND -1))

#unset 'file record'?
[[ "${BCREC}" != '1' ]] && unset BCREC

#process expression
EQ="${*:-$(</dev/stdin)}"
EQ="${EQ//,}"
EQ="${EQ%;}"

#check if a 'record file' can be available
#otherwise, create and initialise one
if [[ -n "${BCREC}" ]]; then
	#init record file if none
	if [[ ! -f "${RECFILE}" ]]; then
		printf '## Bcalc.sh Record\n\n' >> "${RECFILE}"
		printf 'File initialised: %s\n' "${RECFILE}" 1>&2
	fi

	#add note to record
	if [[ -n "${NOTEOPT}" ]]; then
		notef "${*}"
	fi
	
	#swap '$HOLD' by last entry in history, or use last entry if no input
	if [[ "${EQ}" =~ ${HOLD} ]] || [[ -z "${EQ}" ]]; then
		LASTRES=$(tail -1 "${RECFILE}")
		#EQ="${EQ//${HOLD}/${LASTRES}}"
		EQ="$(sed -E "s/$HOLD/${LASTRES}/g" <<<"$EQ")"
		EQ="${EQ:-${LASTRES}}"
	fi
#some error handling
elif [[ -n "${NOTEOPT}" ]]; then
	printf 'A record file is required for adding notes.\n' 1>&2
	exit 1
fi

#load cientific extensions?
[[ -n "${CIENTIFIC}" ]] && setcf

#calc new result and check expression syntax
if RES="$(bc -l <<<"${EXT};${EQ}")"; then
	[[ -z "${RES}" ]] && exit 1
else
	exit 1
fi

#print to record file?
if [[ -n "${BCREC}" ]]; then
	#grep last history entry
	LASTRES="$(tail -1 "${RECFILE}")"

	#check for duplicate entries
	if [[ "${RES}" != 0 ]] && [[ "${RES}" != "${LASTRES}" ]]; then
		{
		#print timestamp
		printf '## %s\n## { %s }\n' "$(date "+%FT%T%Z")" "${EQ}"
		
		#print new result
		printf '%s\n' "${RES}"
		} >> "${RECFILE}"
	fi
fi

#format result

#don't format multiline inputs
if [[ "$(wc -l <<<"${RES}")" -gt 1 ]]; then
	[[ -n "${SCL}${TOPT}" ]] && printf 'Multiline skips formatting options.\n' 1>&2
#thousands separator opt
elif [[ -n "${TOPT}" ]]; then
	printf "%'.${SCL:-2}f\n" "${RES}"
	exit
#user-set scale
elif [[ -n "${SCL}" ]] &&
	#make bc result with user scale
	RESS="$(bc -l <<<"${EXT};scale=${SCL};${EQ}/1" 2>/dev/null)"; then
	#check result
	{ [[ -n "${RESS}" ]] && [[ "${RESS}" != '0' ]];} || unset RESS
#trim trailing noughts; set a big enough scale
elif REST="$(bc -l <<< "define trunc(x){auto os;scale=${SCL:-200};os=scale;for(scale=0;scale<=os;scale++)if(x==x/1){x/=1;scale=os;return x}}; trunc(${RES})" 2>/dev/null)"; then
	#check result
	{ [[ -n "${REST}" ]] && [[ "${REST}" != '0' ]];} || unset REST
fi

#print result
printf '%s\n' "${REST:-${RESS:-${RES}}}"

