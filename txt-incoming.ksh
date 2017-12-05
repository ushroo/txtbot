#!/bin/ksh

./txt-whitelistaws.pl

echo 'twilio aws whitelist updated'
echo 'starting mojolicious endpoint'

morbo -l http://127.0.0.1:3000 ./txt-incoming.pl
