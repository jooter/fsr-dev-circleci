set -x

docker stop priceless_antonelli

docker start priceless_antonelli || \
docker run --name priceless_antonelli -p 1234:1234 -d consensys/lotus-full-node

sleep 5

docker exec  priceless_antonelli bash -c 'cat ~/.lotus/token; echo; /app/lotus/lotus wallet default'

