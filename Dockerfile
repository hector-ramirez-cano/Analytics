# TODO: Swap to -slim for prod
FROM python:3.11 

WORKDIR /analytics

# Dependencies for Postgres driver
RUN apt-get update && apt-get install -y \
    gcc libpq-dev ansible \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend
COPY backend ./backend
COPY ansible/inventory ./ansible/inventory
COPY ansible/playbooks ./ansible/playbooks
COPY ansible/hosts.ini ./ansible/hosts.ini

# Expose port, should be the same as in backend/config.json
EXPOSE 5050

ENV PYTHONUNBUFFERED=1 PYTHONPATH=/analytics ANSIBLE_HOST_KEY_CHECKING=False ANSIBLE_REMOTE_USER="zaph" DEBUG=0

# Run application
CMD ["python", "backend/main.py"]