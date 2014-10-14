docker pull sameersbn/postgresql:latest
docker pull sameersbn/redis:latest
docker pull sameersbn/gitlab:7.3.2-1

docker run --name=gitlab-redis -d sameersbn/redis:latest

docker run --name=gitlab-postgresql -d \
  -e 'DB_NAME=gitlab' -e 'DB_USER=gitlab' -e 'DB_PASS=gitlab' \
  -v /opt/gitlab/db:/var/lib/postgresql \
  sameersbn/postgresql:latest

#docker run --name=gitlab -it --rm \
docker run --name=gitlab -d \
-e 'GITLAB_PORT=10080' -e 'GITLAB_SSH_PORT=10022' \
-p 10022:22 -p 10080:80 \
-v /var/run/docker.sock:/run/docker.sock \
-v $(which docker):/bin/docker \
-v /opt/gitlab/repos:/home/git/data \
--link gitlab-postgresql:postgresql \
--link gitlab-redis:redisio \
sameersbn/gitlab:7.3.2-1