# TODO:Only for testing, remove upon docker-compose file creation
sudo docker build -t analyzer-backend -f Dockerfile .
sudo docker run --rm -it   -p 5000:5000 -v ~/Analyzer_code/identity/id_ed25519:/root/.ssh/id_ed25519:ro   -e ANSIBLE_PRIVATE_KEY_FILE=/root/.ssh/id_ed25519   analyzer-backend
