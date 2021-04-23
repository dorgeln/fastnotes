.ONESHELL:
SHELL := /bin/bash
VERSION := 0.0.15
DOCKER_USER := dorgeln
DOCKER_REPO := fastnotes
PYTHON_VERSION := 3.8.8
PYTHON_REQUIRED := ">=3.8,<3.9"
PYTHON_TAG := python-${PYTHON_VERSION}
NPM_PKG := vega-lite vega-cli canvas configurable-http-proxy
PYTHON_BASE := numpy pandas jupyterlab altair altair_saver nbgitpuller jupyter-server-proxy cysgp4 Pillow jupyterlab-spellchecker pyyaml toml
PYTHON_EXTRA := vega_datasets 

build: deps
	docker image build --target base --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO}  -t ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION} . && \
	docker image build --target devel --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO}  -t ${DOCKER_USER}/${DOCKER_REPO}:devel-${VERSION} . && \
    docker image build --target deploy --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO}  -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} .
bash:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} bash

prune:
	docker system prune -a


deps: 
	[ -f ./package.json ] || npm install --package-lock-only ${NPM_PKG}
	[ -f ./pyproject.toml ] || poetry init -n --python ${PYTHON_REQUIRED}; sed -i 's/version = "0.1.0"/version = "${VERSION}"/g' pyproject.toml; poetry config virtualenvs.path .env;poetry config cache-dir .cache;poetry config virtualenvs.in-project true 
	[ -f ./requirements-base.txt ] || poetry add --lock ${PYTHON_BASE} -v;poetry export --without-hashes -f requirements.txt -o requirements-base.txt
	[ -f ./requirements-extra.txt ] || poetry add --lock ${PYTHON_EXTRA} -v;poetry export --without-hashes -f requirements.txt -o requirements-extra.txt

clean:
	-rm package.json package-lock.json pyproject.toml poetry.lock requirements.txt requirements-base.txt  requirements-extra.txt


tag:
	-while IFS=$$'=' read -r pkg version; do \
		version=$${version//^}; \
		version=$${version//'"'}; \
		version=$${version//' '}; \
		pkg=$${pkg//' '}; \
		case $$version in \
			'') pkg='';version=''  ;;\
			*[a-zA-Z=]*) pkg='';version='' ;; \
    		*) ;; \
		esac; \
		[ ! $$pkg  = '' ] && docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} ${DOCKER_USER}/${DOCKER_REPO}:$$pkg-$$version ; \
	done < pyproject.toml
	docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} ${DOCKER_USER}/${DOCKER_REPO}:latest

push: build
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${VERSION}


push-all: clean-tags build tag
	docker image push -a ${DOCKER_USER}/${DOCKER_REPO}

clean-tags:
	docker images | grep dorgeln/datascience | awk '{system("docker rmi " "'"dorgeln/datascience:"'" $2)}'