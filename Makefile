# Makefile

LOCAL_DOCKER_IMAGE_NAME=jekyll-ari
LOCAL_DOCKER_INSTANCE_NAME=$(LOCAL_DOCKER_IMAGE_NAME)
DOCKER_JEKYLL_PORT=4000
EXPOSED_JEKYLL_PORT=$(DOCKER_JEKYLL_PORT)

all :
	@echo "Use 'make run' to start locally"
	@echo "Use 'make docker' to build"
	@echo "Use 'make docker-run' to run in docker"
	@echo "Use 'make install-jekyll' to install the bundler and jekyll in rbenv"
	@echo "Use 'make clean' to delete the '_site' folder"

docker :
	docker build -t $(LOCAL_DOCKER_IMAGE_NAME) "$(PWD)"

docker-run :
	docker run --rm -p $(DOCKER_JEKYLL_PORT):$(EXPOSED_JEKYLL_PORT) \
		   --name $(LOCAL_DOCKER_INSTANCE_NAME) \
		   -v "$(PWD)":/srv/jekyll \
		   $(LOCAL_DOCKER_IMAGE_NAME)

run :
	arch -x86_64 bundle exec jekyll serve

# https://jekyllrb.com/docs/installation/macos/
install-jekyll: # https://jekyllrb.com/docs/installation/macos/
	arch -x86_64 rbenv install 2.7.1
	arch -x86_64 gem install jekyll bundler
	arch -x86_64 bundler install

clean :
	rm -rf _site


# bundler: failed to load command: jekyll
# https://github.com/jekyll/jekyll/issues/5423
check-jekyll-install:
	arch -x86_64 jekyll --version
	arch -x86_64 bundle exec jekyll --version
