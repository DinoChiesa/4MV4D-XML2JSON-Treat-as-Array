#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-
#
# provision-4mv4d-TreatAsArray-demo.sh
#
# A bash script for importing and deploying an API Proxy.
#
# Last saved: <2016-September-14 15:47:58>
#

verbosity=2
netrccreds=0
apiproxyname="4mv4d-TreatAsArray-demo"
apiproxydir="./bundle"
apiproxyzip=""
envname="test"
defaultmgmtserver="https://api.enterprise.apigee.com"
credentials=""
TAB=$'\t'


function usage() {
  local CMD=`basename $0`
  echo "$CMD: "
  echo "  Imports an API Proxy, and deploys it. "
  echo "  Uses the curl utility."
  echo "usage: "
  echo "  $CMD [options] "
  echo "options: "
  echo "  -o org    the org to use."
  echo "  -e env    the environment to enable API Products on."
  echo "  -u user   Edge admin user for the Admin API calls. You will be prompted for pwd."
  echo "  -n        use .netrc to retrieve credentials (in lieu of -u)"
  echo "  -m url    the base url for the mgmt server."
  echo "  -d dir    directory containing the apiproxy bundle to use. default is ${apiproxydir} "
  echo "  -q        quiet; decrease verbosity by 1"
  echo "  -v        verbose; increase verbosity by 1"
  echo
  echo "Current parameter values:"
  echo "  mgmt api url: $defaultmgmtserver"
  echo "     verbosity: $verbosity"
  echo "   environment: $envname"
  echo
  exit 1
}

## function MYCURL
## Print the curl command, omitting sensitive parameters, then run it.
## There are side effects:
## 1. puts curl output into file named ${CURL_OUT}. If the CURL_OUT
##    env var is not set prior to calling this function, it is created
##    and the name of a tmp file in /tmp is placed there.
## 2. puts curl http_status into variable CURL_RC
function MYCURL() {
  [ -z "${CURL_OUT}" ] && CURL_OUT=`mktemp /tmp/apigee-edge-provision-demo-org.curl.out.XXXXXX`
  [ -f "${CURL_OUT}" ] && rm ${CURL_OUT}
  [ $verbosity -gt 0 ] && echo "curl $@"

  # run the curl command
  CURL_RC=`curl $credentials -s -w "%{http_code}" -o "${CURL_OUT}" "$@"`
  [ $verbosity -gt 0 ] && echo "==> ${CURL_RC}"
}

function CleanUp() {
    [ -f ${CURL_OUT} ] && rm -rf ${CURL_OUT}
    [ -f ${apiproxyzip} ] && rm -rf ${apiproxyzip}
}

function echoerror() { echo "$@" 1>&2; }

function choose_mgmtserver() {
  local name
  echo
  read -p "  Which mgmt server (${defaultmgmtserver}) :: " name
  name="${name:-$defaultmgmtserver}"
  mgmtserver=$name
  echo "  mgmt server = ${mgmtserver}"
}

function choose_credentials() {
  local username password
  read -p "username for Edge org ${orgname} at ${mgmtserver} ? (blank to use .netrc): " username
  echo
  if [[ "$username" = "" ]] ; then  
    credentials="-n"
  else
    echo -n "Org Admin Password: "
    read -s password
    echo
    credentials="-u ${username}:${password}"
  fi
}

function maybe_ask_password() {
  local password
  if [[ ${credentials} =~ ":" ]]; then
    credentials="-u ${credentials}"
  else
    echo -n "password for ${credentials}?: "
    read -s password
    echo
    credentials="-u ${credentials}:${password}"
  fi
}

function check_org() {
  echo "  checking org ${orgname}..."
  MYCURL -X GET  ${mgmtserver}/v1/o/${orgname}
  if [ ${CURL_RC} -eq 200 ]; then
    check_org=0
  else
    check_org=1
  fi
}

function check_env() {
  echo "  checking environment ${envname}..."
  MYCURL -X GET  ${mgmtserver}/v1/o/${orgname}/e/${envname}
  if [ ${CURL_RC} -eq 200 ]; then
    check_env=0
  else
    check_env=1
  fi
}


function produce_and_maybe_show_zip() {
  local curdir zipout 
  apiproxyzip="/tmp/${apiproxyname}.zip"
  
  if [ -f ${apiproxyzip} ]; then
    if [ $verbosity -gt 0 ]; then
      echo "removing the existing zip..."
    fi
    rm -rf ${apiproxyzip}
  fi
  if [ $verbosity -gt 0 ]; then
    echo "Creating the zip..."
  fi

  curdir=`pwd`
  cd "$apiproxydir"

  if [ ! -d apiproxy ]; then
    echo "Error: there is no apiproxy directory in "
    pwd
    echo
    exit 1
  fi

  zipout=`zip -r "${apiproxyzip}" apiproxy  -x "*/*.*~" -x "*/.tern-port" -x "*/Icon*" -x "*/#*.*#"`
  cd "$curdir"

  if [ $verbosity -gt 1 ]; then
    #echo $zipout
    unzip -l "${apiproxyzip}"
    echo
  fi
}

function import_and_deploy_proxy() {
    local rev
    produce_and_maybe_show_zip
    
    # import the proxy bundle (zip)
    if [ $verbosity -gt 0 ]; then
      echo "Importing the bundle as $apiproxyname..."
    fi
    MYCURL -X POST "${mgmtserver}/v1/o/${orgname}/apis?action=import&name=$apiproxyname" -T ${apiproxyzip} -H "Content-Type: application/octet-stream"
    [ $verbosity -gt 1 ] && cat ${CURL_OUT} && echo && echo

    if [ ${CURL_RC} -ne 201 ]; then
      echo
      if [ $verbosity -le 1 ]; then
        cat ${CURL_OUT}
        echo
      fi
      echo "There was an error importing that API bundle..."
      echo
      Cleanup
      exit 1
    fi

    ## what revision did we just import?
    rev=`cat ${CURL_OUT} | grep \"revision\" | tr '\r\n' ' ' | sed -E 's/"revision"|[:, "]//g'`
    echo This is revision $rev

    # deploy (with override) will implicitly undeploy any existing deployed revisions
    MYCURL -X POST -H content-type:application/x-www-form-urlencoded \
        "${mgmtserver}/v1/o/${orgname}/e/${envname}/apis/${apiproxyname}/revisions/${rev}/deployments" \
        -d "override=true&delay=60"

    if [[ ! ${CURL_RC} =~ 200 ]]; then
        echo
        echo "There was an error deploying revision $rev of $apiproxyname."
        cat ${CURL_OUT} 1>&2;
        echo
        exit
    fi
    [ -f ${apiproxyzip} ] && rm -rf ${apiproxyzip}
}



## =======================================================

echo
echo "This script imports and deploys an API Proxy."
echo "=============================================================================="

while getopts "ho:e:u:nm:d:qv" opt; do
  case $opt in
    h) usage ;;
    m) mgmtserver=$OPTARG ;;
    o) orgname=$OPTARG ;;
    e) envname=$OPTARG ;;
    u) credentials=$OPTARG ;;
    n) netrccreds=1 ;;
    d) apiproxydir=$OPTARG ;;
    q) verbosity=$(($verbosity-1)) ;;
    v) verbosity=$(($verbosity+1)) ;;
    *) echo "unknown arg" && usage ;;
  esac
done

echo
if [ "X$mgmtserver" = "X" ]; then
  mgmtserver="$defaultmgmtserver"
fi 

if [ "X$orgname" = "X" ]; then
    echo "You must specify an org name (-o)."
    echo
    usage
    exit 1
fi

if [ "X$envname" = "X" ]; then
    echo "You must specify an environment name (-e)."
    echo
    usage
    exit 1
fi

if [ "X$credentials" = "X" ]; then
  if [ ${netrccreds} -eq 1 ]; then
    credentials='-n'
  else
    choose_credentials
  fi 
else
  maybe_ask_password
fi 

check_org 
if [ ${check_org} -ne 0 ]; then
  echo "that org cannot be validated"
  CleanUp
  exit 1
fi

check_env
if [ ${check_env} -ne 0 ]; then
  echo "that environment cannot be validated"
  CleanUp
  exit 1
fi

import_and_deploy_proxy

CleanUp
exit 0

