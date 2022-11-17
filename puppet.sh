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


function fingerprint(){
        printf "${red}\nRunning HTTPX for port scan...${reset}\n"
        cat subs* | anew > allSubs.txt
        cat allSubs.txt | httpx -ports 80,443,8080,81,3000,3001,8000,8443 -tech-detect -silent -threads 200 -status-code -title -o allScanned.txt
        cat allScanned.txt | awk -F\[ '{print $1}' > allAlive.txt

        printf "${red}\nFingerprinting Webpages...${reset}\n"
        mkdir -p CMS
        cat allAlive.txt | grep "Wordpress" > CMS/wordpress.txt
        cat allAlive.txt | grep "Adobe Experience Manager" > CMS/aem.txt
        cat allAlive.txt | grep "Drupal" > CMS/drupal.txt
}


function nucleiScan(){
        printf "${red}\nRunning Nuclei Scan...${reset}\n"
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
        printf "\n${red}Starting Subdomain Enumeration\n${reset}"
        printf "    ${red}Running Subfinder...${reset}\n"
        subfinder -dL $list -all -silent -o subs1.txt &
        printf "    ${red}Running amass...${reset}\n"
        amass enum -df $list -silent -o subs2.txt &
        printf "    ${red}Running amass bruteforce...${reset}\n"
        amass enum -brute -active -df $list -silent -o subs3.txt &
        wait
elif [ -z "$list" ] && [ "$domain" ]
then
        printf "\n${red}Starting Subdomain Enumeration\n${reset}"
        printf "    ${red}Running Subfinder...${reset}\n"
        subfinder -d $domain -all -silent -o subs1.txt &
        printf "    ${red}Running amass...${reset}\n"
        amass enum -d $domain -silent -o subs2.txt &
        printf "    ${red}Running amass bruteforce...${reset}\n"
        amass enum -brute -active -d $domain -silent -o subs3.txt &
        wait
fi
fingerprint
containered

# Screenshots
printf "${red}\nScreenshot with Aquatone...${reset}\n"
cat allAlive.txt | aquatone -chrome-path ./chrome -silent &

# gau
printf "${red}\nGetting URLs via gau...${reset}\n"
cat allAlive.txt | gau --subs --o allUrls1.txt & > /dev/null

# katana
printf "${red}\nGetting URLs via katana...${reset}\n"
katana -list allAlive.txt -jc -f qurl -c 50 -d 5 -kf all -silent -o allUrls2.txt &
wait

# gf
cat allUrls* | anew allUrls.txt > /dev/null
mkdir -p GF
cat allUrls.txt | gf xss > GF/xss
cat allUrls.txt | gf sqli > GF/sqli
cat allUrls.txt | gf s3-buckets > GF/s3-buckets
cat allUrls.txt | gf ssrf > GF/ssrf
cat allUrls.txt | gf redirect > GF/redirect
cat allUrls.txt | gf ssti > GF/ssti
cat allUrls.txt | gf upload-fields GF/upload-fields
cat allUrls.txt | gf rce > GF/rce
cat allUrls.txt | gf interestingEXT > GF/interestingEXT
cat allUrls.txt | gf img-traversal > GF/img-traversal

# Subdomain takeover checks
printf "${red}\nSQL Injection Scanning with SQLmap...${reset}\n"
subzy -targets allSubs.txt

# Vulnscanning
nucleiScan

# SQLInjection Scanning
printf "${red}\nSQL Injection Scanning with SQLmap...${reset}\n"
sqlmap -m GF/sqli --batch --random-agent --level 1

# SSTI Scanning
printf "${red}\nSSTI Scanning with Tplmap...${reset}\n"
cat GD/ssti | while read line; do python3 /home/shelled/tools/tplmap/tplmap.py -u $line; done

# Vulnscanning
printf "${red}\nVulnerability Scanning with Nmap...${reset}\n"
nmap -sV -iL allSubs.txt -oN scaned-port.txt --script=vuln
