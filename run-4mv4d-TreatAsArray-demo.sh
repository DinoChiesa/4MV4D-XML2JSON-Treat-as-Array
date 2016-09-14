#!/bin/bash
# -*- mode:shell-script; coding:utf-8; -*-
#
# run-4mv4d-TreatAsArray-demo.sh
#
# A bash script for running the TreatAsArray demonstration. 
#
# Last saved: <2016-September-14 15:48:40>
#

verbosity=2
apiproxyname="4mv4d-TreatAsArray-demo"
apiproxydir="./bundle"
apiproxyzip=""
envname="test"
credentials=""
defaultmgmtserver="https://api.enterprise.apigee.com"
TAB=$'\t'

function usage() {
  local CMD=`basename $0`
  echo "$CMD: "
  echo "  Invokes the deployed API Proxy to demonstrate the TreatAsArray option for the XML2JSON policy. "
  echo "  Uses the curl utility."
  echo "usage: "
  echo "  $CMD [options] "
  echo "options: "
  echo "  -o org    the org to use."
  echo "  -e env    the environment to enable API Products on."
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

function getProxyEndpoint() {
    echo -n "https://${orgname}-${envname}.apigee.net/4mv4d-TreatAsArray-demo"
}

function invoke_deployed_proxy() {
    local baseurl=`getProxyEndpoint`
    for url in xform1 xform2 xform2-unwrap ; do
        printf "\nURL path: %s\n" ${baseurl}/${url}
        for fi in example-*.xml ; do
            printf "\nfile: %s\n" $fi
            MYCURL -X POST -H content-type:application/xml -T $fi ${baseurl}/${url}
            if [[ ${CURL_RC} -eq 200 ]]; then
                printf "\nOutput:\n"
                cat ${CURL_OUT}
            else
                printf "some sort of error occurred."
            fi
        done
        printf "\n\n================================================================\n\n"
    done
}


## =======================================================

echo
echo "This script invokes the 4mv4d-TreatAsArray-demo API proxy"
echo "=============================================================================="

while getopts "ho:e:u:nm:d:qv" opt; do
  case $opt in
    h) usage ;;
    o) orgname=$OPTARG ;;
    e) envname=$OPTARG ;;
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


invoke_deployed_proxy

CleanUp
exit 0

