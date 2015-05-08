#!/bin/bash

apt-get install make git curl luarocks libpcre3 libpcre3-dev memcached -y

cpan install Test::Nginx
cpan install Test::Nginx::Socket

