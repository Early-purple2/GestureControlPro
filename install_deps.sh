#!/bin/bash
set -e
cd Server/Python
poetry lock --no-update
poetry install
