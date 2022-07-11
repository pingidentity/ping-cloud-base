#!/bin/bash

if [[ ! -d venv ]]; then
    python -m venv venv
fi

source venv/bin/activate

pip3 install -r requirements.txt
