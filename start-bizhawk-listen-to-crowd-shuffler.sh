#!/bin/bash

export LUA_SCRIPT="$(realpath $(dirname ${BASH_SOURCE}))/bizhawk-crowd-shuffler.lua"

bash "${BIZHAWK_PATH}/EmuHawkMono.sh" "--socket_ip=${HOST}" "--socket_port=${PORT}" "--lua=${LUA_SCRIPT}"
