#!/bin/bash

. /common.sh

expect_flask_user

cd /
FLASK_APP=rest_api flask run --host=0.0.0.0
