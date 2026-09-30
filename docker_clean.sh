
container_name=""
docker rm -v -f $container_name && docker rmi $(docker inspect --format='{{.Image}}' $container_name)


docker container rm -vf $(docker container ls -q) && docker rmi -f $(docker images -q) && docker compose -f ~/workspace/katalist-vault/docker-compose.yml down --volumes && docker volume rm -f $(docker volume ls -q) 