container_name="" # For each container
docker rm -v -f $container_name && docker rmi $(docker inspect --format='{{.Image}}' $container_name)

docker container rm -vf $(docker container ls -q) && docker rmi -f $(docker images -q) && docker volume rm -f $(docker volume ls -q) 