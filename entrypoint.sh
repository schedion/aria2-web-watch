# Start nginx in foreground (container stays up)
echo "[nginx] starting"
exec nginx -g "daemon off;"
