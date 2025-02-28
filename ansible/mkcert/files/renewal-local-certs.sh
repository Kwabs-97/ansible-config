mkcert -cert-file /etc/ssl/local-certs/cert.pem -key-file /etc/ssl/local-certs/key.pem "*.local.test"
systemctl reload nginx 2>/dev/null || true
