# syntax=docker.io/docker/dockerfile:1

FROM mcr.microsoft.com/dotnet/aspnet:10.0

# Add the MS repo to install `libmsquic` to support DNS-over-QUIC + install Cloudflared & Supervisor:
ADD --link https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb /
RUN <<HEREDOC
  dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
  
  # Install tools, libmsquic, supervisor, dan download cloudflared
  apt-get update && apt-get install -y libmsquic dnsutils iputils-ping supervisor curl
  curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
  dpkg -i cloudflared.deb && rm cloudflared.deb
  
  apt-get clean -y && rm -rf /var/lib/apt/lists/*

  # `/etc/dns` is expected to exist the default directory for persisting state:
  mkdir -p /etc/dns
HEREDOC

# Project is built outside of Docker, copy over the build directory:
WORKDIR /opt/technitium/dns
COPY --link ./DnsServerApp/bin/Release/publish /opt/technitium/dns

# Konfigurasi Supervisor untuk menjalankan Technitium & Cloudflared secara berdampingan
RUN <<HEREDOC
  mkdir -p /etc/supervisor/conf.d/
  cat <<'EOF' > /etc/supervisor/conf.d/supervisord.conf
[supervisord]
nodaemon=true

[program:technitium]
command=/usr/bin/dotnet /opt/technitium/dns/DnsServerApp.dll /etc/dns
directory=/opt/technitium/dns
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:cloudflared]
command=bash -c "if [ -n \"$TUNNEL_TOKEN\" ]; then cloudflared tunnel run --token $TUNNEL_TOKEN; else echo 'TUNNEL_TOKEN tidak diisi, melewati cloudflared...'; fi"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF
HEREDOC

# Jalankan via Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

## Only append image metadata below this line:
EXPOSE \
  # Standard DNS service
  53/udp 53/tcp      \
  # DNS-over-QUIC (UDP) + DNS-over-TLS (TCP)
  853/udp 853/tcp    \
  # DNS-over-HTTPS (UDP => HTTP/3) (TCP => HTTP/1.1 + HTTP/2)
  443/udp 443/tcp    \
  # DNS-over-HTTP (for when running behind a reverse-proxy that terminates TLS)
  80/tcp 8053/tcp    \
  # Technitium web console + API (HTTP / HTTPS)
  5380/tcp 53443/tcp \
  # DHCP
  67/udp

LABEL org.opencontainers.image.title="Technitium DNS Server"
LABEL org.opencontainers.image.vendor="Technitium"
LABEL org.opencontainers.image.source="https://github.com/TechnitiumSoftware/DnsServer"
LABEL org.opencontainers.image.url="https://technitium.com/dns/"
LABEL org.opencontainers.image.authors="support@technitium.com"
