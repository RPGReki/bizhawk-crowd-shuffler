#!/bin/bash

export HOST=127.0.0.1
export PORT=7070
export CHANNEL=MyTwitchChannel
export BIZHAWK_PATH=../
export TWITCH_TOKEN=

exec ./bizhawk-crowd-shuffler-linux

# node src
