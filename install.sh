#/bin/bash

#Fetching args for sitename, user and pass
 Defaultvalues
sitename="root"
username="root"
password="root"

print_help() {
    echo "Usage: $0 [--sitename|-s <name>] [--user|-u <user>] [--pass|-p <password>]"
    echo
    echo "Flags:"
    echo "  --sitename, -s     Sitename"
    echo "  --user, -u         Username"
    echo "  --pass, -p         Password"
    echo "  --help             Show this help"
}

# Read args
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -s|--sitename)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                sitename="$2"
                shift
            else
                echo "⚠️  Error: --sitename requires a value."
                exit 1
            fi
            ;;
        -u|--user)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                username="$2"
                shift
            else
                echo "⚠️  Error: --user requires a value."
                exit 1
            fi
            ;;
        -p|--pass)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                password="$2"
                shift
            else
                echo "⚠️  Error: --pass requires a value."
                exit 1
            fi
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "⚠️  Unknown flag:: $1"
            print_help
            exit 1
            ;;
    esac
    shift
done

# Start Docker containers in the background
echo "Starting Docker containers..."
docker compose up -d

# Wait for the database container to become ready
echo "Waiting for the database to be ready..."
until docker exec drupal-db mysqladmin ping -h "localhost" -u root -p'root' --silent; do
    echo "Database not ready yeat. Retrying in 3 seconds..."
    sleep 3;
done
echo "Database is ready!"

# Wait for the Drupal container to be ready to accept Drush commands
echo "Waiting for the Drupal container to be ready..."
until docker exec drupal drush status >/dev/null 2>&1; do
  echo "Drupal not ready yet. Retrying in 3 seconds..."
  sleep 3
done
echo "Drupal container is ready!"

# Check if Drupal is already installed
echo "Checking if Drupal is already installed..."
if ! docker exec drupal drush status --field=bootstrap | grep -q "Successful"; then
  echo "Drupal is not installed. Proceeding with site installation..."
  docker exec drupal drush site-install standard \
    --site-name=$sitename \
    --account-name=$username \
    --account-pass=$password \
    --db-url=mysql://root:root@drupal-db/drupal \
    -y
  echo "Drupal installation completed!"
else
  echo "Drupal is already installed. Skipping installation."
fi