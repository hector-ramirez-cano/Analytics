# TODO:Only for testing, remove upon docker-compose file creation
sudo docker build -t analyzer-backend -f Dockerfile .
sudo docker run --rm -it   -p 5000:5000 -v ~/Analyzer_code/identity/id_ed25519:/root/.ssh/id_ed25519:ro   -e ANSIBLE_PRIVATE_KEY_FILE=/root/.ssh/id_ed25519   analyzer-backend

sudo docker build -t aegis-backend -f Dockerfile .
sudo docker run --rm -it\
    -p 5000:5000 \
    -v ./backend_aegis/identity/id_ed25519:/root/.ssh/id_ed25519:ro \
    -v ./backend_aegis/identity/influx_db.json:/analytics/identity/influx_db.json:ro \
    -v ./backend_aegis/identity/postgres_db.json:/analytics/identity/postgres_db.json:ro \
    -v ./backend_aegis/identity/telegram.json:/analytics/identity/telegram.json:ro \
    -v ./backend_aegis/config.json:/analytics/config.json:ro \
    -e ANSIBLE_PRIVATE_KEY_FILE=/root/.ssh/id_ed25519  \
    aegis-backendcd