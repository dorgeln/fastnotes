.ONESHELL:
SHELL := /bin/bash
VERSION := 0.0.16
DOCKER_USER := dorgeln
DOCKER_REPO := fastnotes
PYTHON_VERSION := 3.8.8
PYTHON_REQUIRED := ">=3.8,<3.9"
PYTHON_TAG := python-${PYTHON_VERSION}
NPM_PKG := vega-lite vega-cli canvas configurable-http-proxy
ALPINE_BASE := sudo bash curl git git-lfs ttf-liberation nodejs npm gettext libffi libzmq sqlite-libs openblas libxml2-utils openssl tar zlib ncurses bzip2 xz libffi pixman cairo pango openjpeg librsvg giflib libpng openblas-ilp64 lapack libxml2 zeromq libnsl libtirpc  libjpeg-turbo tiff freetype libwebp libimagequant lcms2
ALPINE_DEVEL := build-base alpine-sdk g++ expat-dev openssl-dev zlib-dev ncurses-dev bzip2-dev xz-dev sqlite-dev libffi-dev linux-headers readline-dev pixman-dev cairo-dev pango-dev openjpeg-dev librsvg-dev giflib-dev libpng-dev openblas-dev lapack-dev gfortran libxml2-dev zeromq-dev gnupg tar xz expat-dev gdbm-dev libnsl-dev libtirpc-dev pax-utils util-linux-dev xz-dev zlib-dev libjpeg-turbo-dev tiff-dev libwebp-dev libimagequant-dev lcms2-dev cargo
ALPINE_DEPLOY :=  neofetch
PYTHON_BASE := Cython numpy pandas jupyterlab altair altair_saver nbgitpuller jupyter-server-proxy cysgp4 Pillow jupyterlab-spellchecker pyyaml toml matplotlib sshkernel jupyterlab-git
PYTHON_EXTRA :=  asciinema ttygif cowsay lolcat
PYTHON_DEPLOY := vega_datasets 


build: deps
	docker image build --target base --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO}  -t ${DOCKER_USER}/${DOCKER_REPO}:base -t ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION} . 
	docker image build --target build --build-arg VERSION=${VERSION}  --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO}  -t ${DOCKER_USER}/${DOCKER_REPO}:build -t ${DOCKER_USER}/${DOCKER_REPO}:build-${VERSION} .
	docker image build --target deploy --build-arg VERSION=${VERSION} --build-arg PYTHON_VERSION=${PYTHON_VERSION} --build-arg DOCKER_USER=${DOCKER_USER} --build-arg DOCKER_REPO=${DOCKER_REPO}  -t ${DOCKER_USER}/${DOCKER_REPO}:latest -t ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} .

bash:
	docker run -it ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} bash

prune:
	docker system prune -a

deps: 
	[ -f package.json ] || npm install --package-lock-only ${NPM_PKG}
	if [ ! -f package-${VERSION}.json ]; then
		npm install --package-lock-only ${NPM_PKG}
		cp package.json  package-${VERSION}.json
	fi
	if [ ! -f pyproject.toml ]; then 
		poetry init -n --python ${PYTHON_REQUIRED}
		sed -i 's/version = "0.1.0"/version = "${VERSION}"/g' pyproject.toml
		poetry config virtualenvs.path .env
		poetry config cache-dir .cache;poetry config virtualenvs.in-project true 
	fi
	if [ ! -f requirements-base-${VERSION}.txt ]; then
		poetry add -v --lock ${PYTHON_BASE}
		poetry export --without-hashes -f requirements.txt -o requirements-base-${VERSION}.txt
	fi
	if [ ! -f requirements-extra-${VERSION}.txt ]; then 
		poetry add -v --lock ${PYTHON_EXTRA}
		poetry export --without-hashes -f requirements.txt -o requirements-extra-${VERSION}.txt
	fi
	if [ ! -f requirements-deploy-${VERSION}.txt ]; then
		poetry add -v --lock ${PYTHON_DEPLOY}
		poetry export --without-hashes -f requirements.txt -o requirements-deploy-${VERSION}.txt
	fi
	[ -f alpine-base.pkg ] || echo ${ALPINE_BASE} > alpine-base-${VERSION}.pkg
	[ -f alpine-build.pkg ] || echo ${ALPINE_DEVEL} > alpine-build-${VERSION}.pkg
	[ -f alpine-deploy.pkg ] || echo ${ALPINE_DEPLOY} > alpine-deploy-${VERSION}.pkg

clean:
	-rm package*.json package-lock.json pyproject.toml poetry.lock requirements-base*.txt  requirements-extra*.txt requirements-deploy*.txt alpine-base*.pkg alpine-build*.pkg  alpine-deploy*.pkg 


tag: build
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
	docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} ${DOCKER_USER}/${DOCKER_REPO}:${PYTHON_TAG}
	docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} ${DOCKER_USER}/${DOCKER_REPO}:stable
	docker tag ${DOCKER_USER}/${DOCKER_REPO}:${VERSION} ${DOCKER_USER}/${DOCKER_REPO}:latest

push: build
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:${VERSION}
	docker image push ${DOCKER_USER}/${DOCKER_REPO}:latest

push-all: clean-tags build tag
	docker image push -a ${DOCKER_USER}/${DOCKER_REPO}

clean-tags:
	docker images | grep dorgeln/datascience | awk '{system("docker rmi " "'"dorgeln/datascience:"'" $2)}'

install: 
	poetry install -vvv
	npm install --verbose --unsafe-perm
