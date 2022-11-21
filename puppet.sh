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
        subfinder -dL $list -all -o subs1.txt
        printf "    ${red}Running amass...${reset}\n"
        amass enum -df $list -o subs2.txt
        printf "    ${red}Running amass bruteforce...${reset}\n"
        amass enum -brute -active -df $list -o subs3.txt
elif [ -z "$list" ] && [ "$domain" ]
then
        printf "\n${red}Starting Subdomain Enumeration\n${reset}"
        printf "    ${red}Running Subfinder...${reset}\n"
        subfinder -d $domain -all -o subs1.txt
        printf "    ${red}Running amass...${reset}\n"
        amass enum -d $domain -o subs2.txt
        printf "    ${red}Running amass bruteforce...${reset}\n"
        amass enum -brute -active -d $domain -o subs3.txt
fi

# Subdomain Permutations
printf "${red}\nRunning Subdomain Permutations with RipGen...${reset}\n"
cat subs* | anew allSubs.txt
cat allSubs.txt | ripgen > ripgen.txt
numPerms=($(wc ripgen.txt))
printf "${red}\nNumber of Subdomain Permutations: ${reset}"
printf "$numPerms\n"
if [ $numPerms -gt 2000000 ]
then
        printf "${red}Taking first 2,000,000 permutations due to configutation...\n${reset}"
fi
head -n 2000000 ripgen.txt > allPerms.txt

# Subdomain Permutations Duplicate Removal
printf "${red}\nRemoving Duplicates from Subdomain Permutation...${reset}\n"
cat allPerms.txt | sort -u > allPermsTrimmed.txt
numPermsTrimmed=($(wc allPermsTrimmed.txt))
printf "${red}\nNumber of Subdomain Permutations Trimmed: ${reset}"
printf "$numPermsTrimmed\n"

# DNS Resolution
printf "${red}\nRunning DNS Resolution with dnsx on Permutation Subdomains...${reset}\n"
cat allPermsTrimmed.txt | dnsx -o allAlivePerms.txt

printf "${red}\nRunning DNS Resolution with dnsx on Recon Subdomains...${reset}\n"
cat allSubs.txt | dnsx -o allAliveRecon.txt

# Merging Permutations with Subdomains
printf "${red}\nMerging Permutations and Subdomains...${reset}\n"
cp allAliveRecon.txt allAlive.txt
cat allAlivePerms.txt | anew allAlive.txt

# Port Scanning
printf "${red}\nRunning Port Scan with naabu...${reset}\n"
naabu -l allAlive.txt -p- -o allPorts.txt

# Finger Printing
printf "${red}\nFingerprinting Webpages...${reset}\n"
cat allAlive.txt | httpx -ports 80,443,8080,8443 -tech-detect -silent -threads 200 -status-code -title -follow-redirects -o allScanned.txt
cat allScanned.txt | awk -F\[ '{print $1}' > allAliveWeb.txt
mkdir -p CMS
cat allAliveWeb.txt | grep -i "Wordpress" > CMS/wordpress.txt
cat allAliveWeb.txt | grep -i "Adobe Experience Manager" > CMS/aem.txt
cat allAliveWeb.txt | grep -i "Drupal" > CMS/drupal.txt

# gau
printf "${red}\nGetting URLs via gau...${reset}\n"
cat allAlive.txt | gau --subs --threads 200 --o allUrls1.txt

# katana
printf "${red}\nGetting URLs via katana...${reset}\n"
katana -list allAliveWeb.txt -jc -f qurl -c 50 -d 5 -kf all -o allUrls2.txt

# gf
cat allUrls* | anew allUrls.txt
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

# Vulnscanning
printf "${red}\nRunning Nuclei Scan...${reset}\n"
git -C ~/nuclei-templates stash
git -C ~/nuclei-templates pull
cat allAliveWeb.txt | nuclei -t ~/nuclei-templates -es info -o nuclei.txt

# SQLInjection Scanning
printf "${red}\nSQL Injection Scanning with SQLmap...${reset}\n"
sqlmap -m GF/sqli --batch --random-agent --level 1

# SSTI Scanning
printf "${red}\nSSTI Scanning with Tplmap...${reset}\n"
cat GF/ssti | while read line; do python3 /home/shelled/tools/tplmap/tplmap.py -u $line; done
