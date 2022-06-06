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
	bundle exec jekyll serve --host 0.0.0.0
	#arch -x86_64 bundle exec jekyll serve --host 0.0.0.0

# https://jekyllrb.com/docs/installation/macos/
# 2022-06-02 new:
# brew install chruby ruby-install
# ruby-install ruby
# echo "source $(brew --prefix)/opt/chruby/share/chruby/chruby.sh" >> ~/.zshrc
# echo "source $(brew --prefix)/opt/chruby/share/chruby/auto.sh" >> ~/.zshrc
# echo "chruby ruby-3.1.1" >> ~/.zshrc
# echo "source $(brew --prefix)/opt/chruby/share/chruby/chruby.sh" >> ~/.bash_profile
# echo "source $(brew --prefix)/opt/chruby/share/chruby/auto.sh" >> ~/.bash_profile
# echo "chruby ruby-3.1.2" >> ~/.bash_profile
# relaunch terminal
# ruby -v # show 3.1.2p20
# gem install jekyll
#
# Also:
# bundle add webrick


install-jekyll-x86: # https://jekyllrb.com/docs/installation/macos/
	arch -x86_64 rbenv install 2.7.1
	arch -x86_64 gem install jekyll bundler
	arch -x86_64 bundler install

install-jekyll: # https://jekyllrb.com/docs/installation/macos/
	rbenv install 2.7.1
	gem install jekyll bundler
	bundler install

clean :
	rm -rf _site


# bundler: failed to load command: jekyll
# https://github.com/jekyll/jekyll/issues/5423
check-jekyll-install-x86:
	arch -x86_64 jekyll --version
	arch -x86_64 bundle exec jekyll --version
