FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /source

# Copy seluruh source code repo dan publish
COPY . .
RUN dotnet publish DnsServerApp/DnsServerApp.csproj -c Release -o /app/publish

# STAGE 2: Runtime Image + Cloudflared + Supervisor
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /opt/technitium/dns

# Install supervisor, cloudflared, dan tools pendukung
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl dnsutils iputils-ping supervisor ca-certificates && \
    curl -sSL -o /tmp/cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i /tmp/cloudflared.deb && rm /tmp/cloudflared.deb && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/* && \
    mkdir -p /etc/dns /etc/supervisor/conf.d

# Copy hasil compile dari STAGE 1
COPY --from=build-env /app/publish /opt/technitium/dns

# Konfigurasi Supervisord untuk jalankan Technitium + Cloudflared
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

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
