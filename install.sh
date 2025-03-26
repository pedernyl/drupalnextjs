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

# Get container names from Docker Compose service names
DRUPAL_CONTAINER=$(docker compose ps -q drupal)
DB_CONTAINER=$(docker compose ps -q db)

# Wait for the database container to become ready
echo "Waiting for the database to be ready..."
until docker exec "$DB_CONTAINER" mysqladmin ping -h "localhost" -u root -p'root' --silent; do
    echo "Database not ready yeat. Retrying in 3 seconds..."
    sleep 3;
done
echo "Database is ready!"

# Wait for the Drupal container to be ready to accept Drush commands
echo "Waiting for the Drupal container to be ready..."
until docker exec "$DRUPAL_CONTAINER" drush status >/dev/null 2>&1; do
  echo "Drupal not ready yet. Retrying in 3 seconds..."
  sleep 3
done
echo "Drupal container is ready!"

# Check if Drupal is already installed
echo "Checking if Drupal is already installed..."

if ! docker exec drupal drush status --field=bootstrap | grep -q "Successful"; then
  echo "Drupal is not installed. Preparing file system and installing..."

  echo "Getting Drupal root path..."
  DRUPAL_ROOT=$(docker exec "$DRUPAL_CONTAINER" drush status | grep "Drupal root" | awk -F': ' '{print $2}' | xargs | tr -d '\r')
  echo "Drupal root is: $DRUPAL_ROOT"

  # Exit if root path couldn't be determined
  if [ -z "$DRUPAL_ROOT" ]; then
    echo "❌ Failed to detect Drupal root path. Aborting script."
    exit 1
  fi

  echo "Detecting web server user inside the container..."
  APACHE_USER=$(docker exec "$DRUPAL_CONTAINER" ps aux | grep -E 'apache2|httpd|php-fpm' | grep -v root | awk '{print $1}' | head -n 1)
  echo "Detected web server user: $APACHE_USER"

  if [ -z "$APACHE_USER" ]; then
    echo "❌ Failed to detect web server user. Aborting script."
    exit 1
  fi
  echo "Setting correct file permissions for Drupal..."
  docker exec "$DRUPAL_CONTAINER" chmod -R ug+w "$DRUPAL_ROOT/sites/default"
  docker exec "$DRUPAL_CONTAINER" mkdir -p "$DRUPAL_ROOT/sites/default/files"
  docker exec "$DRUPAL_CONTAINER" chmod -R ug+w "$DRUPAL_ROOT/sites/default/files"
  docker exec "$DRUPAL_CONTAINER" chown -R "$APACHE_USER:$APACHE_USER" "$DRUPAL_ROOT/sites/default"
  echo "✅ Permissions and ownership set!"
  
  docker exec "$DRUPAL_CONTAINER" drush site-install standard \
  --site-name="$sitename" \
  --account-name="$username" \
  --account-pass="$password" \
  --db-url="mysql://drupal:drupal@db/drupal" \
  -y

  #adding graphql
  echo "Installing GraphQL module via Composer..."
  docker exec "$DRUPAL_CONTAINER" composer require drupal/graphql  
  echo "Enabling GraphQL module..."
  docker exec "$DRUPAL_CONTAINER" drush en graphql -y

  echo "Drupal installation and GraphQL activation completed!"
  
else
  echo "Drupal is already installed. Skipping installation."
fi