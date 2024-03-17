#!/bin/bash

function getpara()
{ 
    FILENAME=$1; SECTION=$2; KEY=$3
    RESULT=`awk '/\['$SECTION'\]/{a=1}a==1&&$1~/'$KEY'/{print $1}' $FILENAME | grep $KEY= | awk -F '=' '{print $2;exit}'`
    eval echo $RESULT
}

getpara $1 $2 $3
