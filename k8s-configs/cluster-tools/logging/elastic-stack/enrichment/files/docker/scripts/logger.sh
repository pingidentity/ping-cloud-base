#!/usr/bin/env sh

logger()
{
    msg=""
    stream_num=1
    case $1 in
        INFO)
            msg=$2
            stream_num=1
            ;;
        WARNING)
            msg=$2
            stream_num=1
            ;;
        ERROR)
            msg=$2
            stream_num=2
            ;;
        *)
            msg="Wrong log type was received!"
            stream_num=2
            ;;
    esac

    printf "$(date +'%FT%T.%3N')\t$msg\n" >&$stream_num
}