# xxxsyntax=docker/dockerfile:1.3
FROM ubuntu

# based on https://rasika90.medium.com/how-i-saved-tons-of-gbs-with-https-caching-41550b4ada8a
# https://support.kaspersky.com/KWTS/6.0/en-US/166244.htm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update
RUN TZ=Etc/UTC apt-get -y install tzdata
RUN apt-get install -y build-essential openssl libssl-dev pkg-config perl
RUN apt-get install -y wget eatmydata




RUN wget http://www.squid-cache.org/Versions/v5/squid-5.3.tar.gz
RUN tar -xvf squid-5.3.tar.gz

WORKDIR squid-5.3
RUN ./configure --help
RUN eatmydata ./configure \
    --with-default-user=proxy  \
    --with-openssl  \
    --enable-ssl-crtd \
    --disable-arch-native
#    --prefix=/local/squid  \
#    --with-logdir=/usr/local/squid/log/squid  \
#    --with-pidfile=/usr/local/squid/run/squid.pid
RUN eatmydata make
RUN eatmydata make install
#RUN date

FROM ubuntu
COPY --from=0 --chown=proxy:proxy /usr/local /usr/local

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y openssl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "[ v3_ca ]" >> /etc/ssl/openssl.cnf
RUN echo "keyUsage = cRLSign, keyCertSign" >> /etc/ssl/openssl.cnf

RUN mkdir -p /usr/local/squid/etc/ssl_cert
WORKDIR /usr/local/squid/etc/ssl_cert
RUN  openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -extensions v3_ca -keyout squid-self-signed.key -out squid-self-signed.crt -subj '/O=<CompanyName>/OU=<Department>/CN=<CommonName>'
# Convert the cert into a trusted certificate in DER format.
RUN openssl x509 -in squid-self-signed.crt -outform DER -out squid-self-signed.der
# Convert the cert into a trusted certificate in PEM format.
RUN openssl x509 -in squid-self-signed.crt -outform PEM -out squid-self-signed.pem
# Generate the settings file for the Diffie-Hellman algorithm.
RUN openssl dhparam -outform PEM -out squid-self-signed_dhparam.pem 2048

COPY root/ /
#RUN groupadd  -r proxy -g 433
#RUN useradd -u 431 -r -g proxy -s /sbin/nologin -c "Docker image user" proxy

RUN mkdir -p /usr/local/squid/var/logs/
RUN /usr/local/squid/libexec/security_file_certgen -c -s /usr/local/squid/var/ssl_db -M 20MB

#RUN chown -R proxy:proxy /usr/local/squid/log/
#RUN chown -R proxy:proxy /usr/local/squid/var/logs/ssl_db
#RUN chown -R proxy:proxy /usr/local/squid/etc/ssl_cert/
#RUN chown -R proxy:proxy /usr/local/squid/run/

#USER squid





#RUN chsh -s /bin/bash proxy
#RUN su - proxy -c "/usr/local/squid/sbin/squid -z -d 100 --foreground"

RUN /usr/local/squid/sbin/squid -v
RUN /usr/local/squid/sbin/squid -z -d 100 --foreground
RUN ls -la /usr/local/squid/var/cache/squid

EXPOSE 3128/tcp

##Let’s add our CA cert as a trusted CA into local machine.
RUN cp /usr/local/squid/etc/ssl_cert/squid-self-signed.pem /usr/local/share/ca-certificates/squid-self-signed.crt
RUN update-ca-certificates

CMD ["/usr/local/squid/sbin/squid", "-d", "10", "--foreground"]




