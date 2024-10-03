#!/bin/bash
echo deleting unpackaged and scratch-org data

cp -r unpackaged/ force-app 2>/dev/null

echo deploying unpackaged

sf project deploy start --source-dir force-app/unpackaged --json

rm -rf force-app/unpackaged 2>/dev/null