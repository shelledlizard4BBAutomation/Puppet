#!/usr/bin/env bash

# TERM COLORS
bred='\033[1;31m'
bblue='\033[1;34m'
bgreen='\033[1;32m'
byellow='\033[1;33m'
red='\033[0;31m'
blue='\033[0;34m'
green='\033[0;32m'
yellow='\033[0;33m'
reset='\033[0m'

function help(){
	echo "Usage: puppet [ -l | --list ]
			[ -d | --domain]
			[ -h | --help]"
	exit 2
}

function banner(){
	printf "\n\n${red}"
	printf "   ▄███████▄ ███    █▄     ▄███████▄    ▄███████▄    ▄████████     ███     \n"
	printf "  ███    ███ ███    ███   ███    ███   ███    ███   ███    ███ ▀█████████▄ \n"
	printf "  ███    ███ ███    ███   ███    ███   ███    ███   ███    █▀     ▀███▀▀██ \n"
	printf "  ███    ███ ███    ███   ███    ███   ███    ███  ▄███▄▄▄         ███   ▀ \n"
	printf "▀█████████▀  ███    ███ ▀█████████▀  ▀█████████▀  ▀▀███▀▀▀         ███     \n"
	printf "  ███        ███    ███   ███          ███          ███    █▄      ███     \n"
	printf "  ███        ███    ███   ███          ███          ███    ███     ███     \n"
	printf "▄████▀      ████████▀   ▄████▀       ▄████▀        ██████████    ▄████▀    \n"
	printf " \nVersion 0.1                                                 by @shelled${reset}\n"
}


function subdomains(){
	printf "\n${red}Starting Subdomain Enumeration\n${reset}" 
	if [ $TYPE = "list" ] 
	then		
		printf "    ${red}Running Subfinder...${reset}\n"
		subfinder -dL $list -all -silent -o subs1.txt &
		printf "    ${red}Running amass...${reset}\n"
		amass enum -df $list -silent -o subs2.txt             &
		printf "    ${red}Running amass bruteforce...${reset}\n"
		amass enum -brute -df $list -silent -o subs3.txt      &
		wait
	else
		printf "    ${red}Running Subfinder...${reset}\n"
		subfinder -d $domain -all -silent -o subs1.txt &
		printf "    ${red}Running amass...${reset}\n"
		amass enum -d $domain -silent -o subs2.txt             &
		printf "    ${red}Running amass bruteforce...${reset}\n"
		amass enum -brute -d $domain -silent -o subs3.txt      &
		wait
	fi
}

function fingerprint(){
	printf "${red}Running HTTPX for ports 80,443,8080...${reset}\n"
	cat subs* | anew > allSubs.txt
	cat allSubs.txt | httpx -ports 80,443,8080 -tech-detect -silent -o allAlive.txt

	printf "${red}Fingerprinting Webpages...${reset}\n"
	cat allAlive.txt | grep "Wordpress" > wordpress.txt
	cat allAlive.txt | grep "Adobe Experience Manager" > aem.txt
	cat allAlive.txt | grep "Drupal" > drupal.txt
}

function nucleiScan(){
	printf "${red}Running Nuclei Scan...${reset}\n"
	git -C ~/nuclei-templates stash
	git -C ~/nuclei-templates pull
	cat allAlive.txt | nuclei -t ~/nuclei-templates -es info -o nuclei.txt
}

SHORT=l:,d:,h
LONG=list:,domain:,help
OPTS=$(getopt -a -n puppet --options $SHORT --longoptions $LONG -- "$@")

VALID_ARGUMENTS=$# # Returns the count of arguments that are in short or long options

if [ "$VALID_ARGUMENTS" -eq 0 ]; then
	help
fi

eval set -- "$OPTS"

while :
do 
	case "$1" in
		-l | --list)
			list="$2"
			shift 2
			;;
		-d | --domain)
			domain="$2"
			shift 2
			;;
		-h | --help)
			help
			;;
		--)
			shift;
			break
			;;
		*)
			echo "Unexpected option: $1"
			help
			;;
	esac
done

banner
if [ "$list" ] && [ -z "$domain" ]
then
	TYPE="list"
	subdomains
elif [ -z "$list" ] && [ "$domain" ]
then
	TYPE="domain"
	subdomains
fi
fingerprint
nucleiScan
