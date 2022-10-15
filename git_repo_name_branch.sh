#!/bin/bash
git --version 2>&1 >/dev/null 
GIT_IS_AVAILABLE=$?

if [ $GIT_IS_AVAILABLE -eq 0 ]; then
    clear
    echo -ne "\e[33m"
    basename -z $(git rev-parse --show-toplevel 2> /dev/null)
    echo -ne "\e[0m "
    echo -ne "\e[35m" # echo -ne "\e[96m" 
    git rev-parse --abbrev-ref HEAD 2> /dev/null
    echo -ne "\e[0m"
fi