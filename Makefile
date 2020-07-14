# Makefile

LOCAL_DOCKER_IMAGE_NAME=jekyll-ari
LOCAL_DOCKER_INSTANCE_NAME=$(LOCAL_DOCKER_IMAGE_NAME)
DOCKER_JEKYLL_PORT=4000
EXPOSED_JEKYLL_PORT=$(DOCKER_JEKYLL_PORT)

all :
	@echo "Use 'make docker' to build"
	@echo "Use 'make docker-run' to run in docker"

docker :
	docker build -t $(LOCAL_DOCKER_IMAGE_NAME) "$(PWD)"

docker-run :
	docker run --rm -p $(DOCKER_JEKYLL_PORT):$(EXPOSED_JEKYLL_PORT) \
		   --name $(LOCAL_DOCKER_INSTANCE_NAME) \
		   -v "$(PWD)":/srv/jekyll \
		   $(LOCAL_DOCKER_IMAGE_NAME)

run :
	bundle exec jekyll serve

install-jekyll: # https://jekyllrb.com/docs/installation/macos/
	rbenv install 2.7.1
	gem install jekyll bundler

clean :
	rm -rf _site

