FROM technitium/dns-server:latest

USER root

# Install supervisor, cloudflared, dan openssl
RUN apt-get update && \
    apt-get install -y --no-install-recommends supervisor curl ca-certificates bash openssl && \
    curl -sSL -o /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i /tmp/cloudflared.deb && rm /tmp/cloudflared.deb && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /etc/supervisor/conf.d

# Generate Sertifikat Self-Signed .pfx Otomatis saat build (Password: 123456)
RUN openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout /etc/dns/cert.key \
    -out /etc/dns/cert.crt \
    -days 3650 \
    -subj "/CN=liatdns.dfat.my.id" && \
    openssl pkcs12 -export \
    -out /etc/dns/cert.pfx \
    -inkey /etc/dns/cert.key \
    -in /etc/dns/cert.crt \
    -passout pass:123456

# Bikin konfigurasi supervisor
RUN echo '[supervisord]' > /etc/supervisor/conf.d/supervisord.conf && \
    echo 'nodaemon=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '[program:technitium]' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'command=/usr/bin/dotnet /opt/technitium/dns/DnsServerApp.dll /etc/dns' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'directory=/opt/technitium/dns' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo '[program:cloudflared]' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'command=bash -c "if [ -n \"$TUNNEL_TOKEN\" ]; then cloudflared tunnel run --token $TUNNEL_TOKEN; else echo \"TUNNEL_TOKEN kosong, skip cloudflared...\"; fi"' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autostart=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'autorestart=true' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stdout_logfile=/dev/stdout' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stdout_logfile_maxbytes=0' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stderr_logfile=/dev/stderr' >> /etc/supervisor/conf.d/supervisord.conf && \
    echo 'stderr_logfile_maxbytes=0' >> /etc/supervisor/conf.d/supervisord.conf

EXPOSE 53/udp 53/tcp 853/tcp 443/tcp 80/tcp 5380/tcp

ENTRYPOINT []
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
