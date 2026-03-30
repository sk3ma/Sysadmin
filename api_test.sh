#!/usr/bin/env bash

CYAN="\033[1;36m"
RESET="\033[0m"
YELLOW="\033[33m"

echo -e "${CYAN}"
cat << "STOP"
         _                   _        _     
        / /\                /\ \     /\ \   
       / /  \              /  \ \    \ \ \  
      / / /\ \            / /\ \ \   /\ \_\ 
     / / /\ \ \          / / /\ \_\ / /\/_/ 
    / / /  \ \ \        / / /_/ / // / /    
   / / /___/ /\ \      / / /__\/ // / /     
  / / /_____/ /\ \    / / /_____// / /      
 / /_________/\ \ \  / / /   ___/ / /__     
/ / /_       __\ \_\/ / /   /\__\/_/___\    
\_\___\     /____/_/\/_/    \/_________/  
STOP
echo -e "${RESET}"
echo

echo -ne "${YELLOW}API URL: ${RESET}"
read URL
echo -ne "${YELLOW}API Token / Password: ${RESET}"
read -s TOKEN
echo

echo -ne "${YELLOW}Auth type (bearer/basic/none) [bearer]: ${RESET}"
read AUTH_TYPE
AUTH_TYPE="${AUTH_TYPE:-bearer}"

if [[ "$AUTH_TYPE" == "basic" ]]; then
  echo -ne "${YELLOW}Username: ${RESET}"
  read USERNAME
fi

echo -ne "${YELLOW}Method [GET]: ${RESET}"
read METHOD
METHOD="${METHOD:-GET}"

echo -ne "${YELLOW}Body (optional): ${RESET}"
read BODY

echo
echo "${METHOD} ${URL}"
echo "----------------------------------"

CURL_CMD=(curl -s -X "${METHOD}" "${URL}" -H "Content-Type: application/json")

if [[ "$AUTH_TYPE" == "bearer" && -n "${TOKEN}" ]]; then
  CURL_CMD+=(-H "Authorization: Bearer ${TOKEN}")
elif [[ "$AUTH_TYPE" == "basic" && -n "${TOKEN}" ]]; then
  CURL_CMD+=(-u "${USERNAME}:${TOKEN}")
fi

if [[ -n "${BODY}" ]]; then
  CURL_CMD+=(-d "${BODY}")
fi

RESPONSE="$("${CURL_CMD[@]}" -w "\nHTTP_STATUS:%{http_code}")"
HTTP_STATUS="$(echo "${RESPONSE}" | sed -n 's/.*HTTP_STATUS://p')"
BODY="$(echo "${RESPONSE}" | sed 's/HTTP_STATUS:.*//')"

if [[ "${HTTP_STATUS}" =~ ^2 ]]; then
  COLOR="\033[0;32m"
elif [[ "${HTTP_STATUS}" =~ ^4|^5 ]]; then
  COLOR="\033[0;31m"
else
  COLOR="\033[0;33m"
fi

RESET="\033[0m"

if echo "${BODY}" | jq . >/dev/null 2>&1; then
  echo "${BODY}" | jq .
else
  echo "${BODY}"
fi

echo
echo -e "Status: ${COLOR}${HTTP_STATUS}${RESET}"
