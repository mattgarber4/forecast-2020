#!/bin/bash
# Script to invoke all forecast ec2 processes

## facebook data update
/usr/lib/R/bin/Rscript './ec2/fb_db_update.R' >> './ec2/fb_db_update.log' 2>&1

## run predictit scripts
/usr/local/aws-cli/v2/current/bin/aws lambda invoke --function-name scrape_predictit response.json
/usr/local/aws-cli/v2/current/bin/aws lambda invoke --function-name scrape_predictit2 response.json
/usr/local/aws-cli/v2/current/bin/aws lambda invoke --function-name scrape_predictit3 response.json