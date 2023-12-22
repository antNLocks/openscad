docker stop bookworm-openscad-devcontainer_c
vsc_image=$(docker ps -a | grep bookworm-openscad-devcontainer_c | awk '{print $2}')
docker rm bookworm-openscad-devcontainer_c
docker image rm bookworm-openscad-devcontainer
docker image rm $vsc_image
docker volume prune -f -a