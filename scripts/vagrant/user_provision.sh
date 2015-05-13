#!/bin/bash

cd /ngx_borderpatrol
make distclean
make

# Setup ruby version and gemset
gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
`\curl -sSL https://get.rvm.io | bash`

source /home/vagrant/.rvm/scripts/rvm

`rvm install ruby-1.9.3-p551`

echo '1.9.3' > .ruby-version
echo 'borderpatrol' > .ruby-gemset
source /home/vagrant/.rvm/scripts/rvm
cd .

bundle install
make test

# bring up services
god -c t/borderpatrol.god
