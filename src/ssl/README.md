This folder contains self-signed SSL key and certs which will be used for local testing with your browser:

Generate new ones via (won't be needed though):

    openssl genrsa -out server.key 2048
    openssl req -new -sha256 -key server.key -out server.csr
    openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt

Additional details can be found <a href="https://www.digitalocean.com/community/articles/how-to-create-a-ssl-certificate-on-nginx-for-ubuntu-12-04">here</a>.
