# MAINTAINER Kiru Samapathy

# Project name
ORG=org
REGISTRY=local
PROJECT_GROUP=group
PROJECT=project

ifdef bamboo_working_directory
MOUNT_DIR = $(bamboo_working_directory)
else
MOUNT_DIR = $(PWD)
endif

all: test image publish

clean:
	rm -rf build

copy: clean
	mkdir -p build
	cp src/templates/Dockerfile.tmpl build/Dockerfile
	cp -r src/bash/. build/.
	cp -r src/config/. build/.
	cp -r src/dashboards build/.
	cp -r src/scripts build/.

test-ci:
	@docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock
		-v ${MOUNT_DIR}:/workspace \
		 ruby \
		 make -C workspace/ test

test: copy
	@echo "Installing dependent gems and running spec"
	bundle install
	bundle exec rspec --format documentation

dev: copy test
	@echo "Spinning up the Grafana Docker container locally named grafana-interface-dev"
	@docker stop grafana-interface-dev || echo 'Dev container is not running'
	@docker rm grafana-interface-dev || echo 'Dev container is not running'
	@docker run -d --name grafana-interface-dev -p 3000:3000 -v ${MOUNT_DIR}/src/dashboards/:/var/lib/grafana/dashboards/ grafana-interface-spec:latest
	@echo "Open Grafana dashboard @ http://localhost:3000"
	docker exec -ti grafana-interface-dev /bin/bash

image: copy
	@echo "$(ORG) Preparing Docker image for grafana_interface"
	@docker build --build-arg DEPLOY_ENVIRONMENT=$(BAMBOO_DEPLOY_ENVIRONMENT) -t $(ORG)/$(PROJECT) build/

publish:
	@echo "Publishing image to $(ORG) registry "
	@docker tag $(ORG)/$(PROJECT) $(REGISTRY)/$(PROJECT_GROUP)/$(PROJECT)
	@docker login -u $(bamboo_DOCKER_USER) -p $(bamboo_DOCKER_PASSWORD)
	@docker push $(REGISTRY)/$(PROJECT_GROUP)/$(PROJECT)

.PHONY: all clean copy test image publish
