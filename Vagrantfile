# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.ssh.forward_agent = true

  config.vm.box = "hashicorp/precise64"
  config.vm.provision :shell, :path => "scripts/vagrant/provision.sh"
  config.vm.provision :shell, :path => "scripts/vagrant/user_provision.sh",
                              :privileged => false

  config.vm.synced_folder "../ngx_borderpatrol", "/ngx_borderpatrol", type: "rsync", rsync__exclude: File.read(".gitignore").split("\n").select{ |str| str =~ /[^#]/}
  config.vm.network "forwarded_port", :guest => 4443, :host => 8443 

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--memory", "2048"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "off"]
  end
end
