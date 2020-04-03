#!/usr/bin/env bash

set -ex

packageFunction () {
    pushd $1
    python3 -m pip install -r requirements.txt --target ./package --system
    pushd package
    zip -r9 ${OLDPWD}/function.zip .
    popd
    zip -g function.zip lambda_function.py
    popd
    mv $1/function.zip $1.zip
}

# Package s3esdelete
packageFunction s3esdelete

# Package s3esindex
packageFunction s3esindex