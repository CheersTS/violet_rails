RAILS_ENV=test
echo "Setting: RAILS_ENV=$RAILS_ENV"

docker-compose run --rm solutions_test rails test -f --verbose