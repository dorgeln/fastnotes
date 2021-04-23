ARG VERSION
ARG DOCKER_USER
ARG DOCKER_REPO

FROM alpine:edge as base

LABEL maintainer="Andreas Trawöger <atrawog@dorgeln.org>" org.dorgeln.version=${VERSION} 

ARG VERSION
ARG PYTHON_VERSION
ARG DOCKER_USER
ARG DOCKER_REPO
ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

RUN apk add --no-cache sudo curl bash git ttf-liberation nodejs npm gettext libffi libzmq sqlite-libs openblas libxml2-utils openssl tar zlib ncurses bzip2 xz libffi pixman cairo pango openjpeg librsvg giflib libpng openblas-ilp64 lapack libxml2 zeromq libnsl libtirpc  libjpeg-turbo tiff freetype libwebp libimagequant lcms2

RUN adduser --disabled-password  -u ${NB_UID} -G users ${NB_USER} && \
    addgroup -g ${NB_UID}  ${NB_USER} && \
    adduser ${NB_USER} ${NB_USER} && \
    adduser ${NB_USER} wheel

RUN echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel && chmod 0440 /etc/sudoers.d/wheel

ENV ENV_ROOT="/env" 
ENV PYENV_ROOT=${ENV_ROOT}/pyenv \
    NPM_DIR=${ENV_ROOT}/npm 
ENV PATH="${PYENV_ROOT}/shims:${PYENV_ROOT}/bin:${NPM_DIR}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN sed -i "s/^export PATH=/#export PATH=L/g" /etc/profile
RUN mkdir -p ${ENV_ROOT} ${NPM_DIR} && chown -R ${NB_USER}.${NB_GID} ${ENV_ROOT}

USER ${NB_USER}

ENV PYTHONUNBUFFERED=true \
    PYTHONDONTWRITEBYTECODE=true \
    PIP_NO_CACHE_DIR=true \
    PIP_DISABLE_PIP_VERSION_CHECK=true \
    PIP_DEFAULT_TIMEOUT=180 \
    NODE_PATH=${NPM_DIR}/node_modules \
    NPM_CONFIG_GLOBALCONFIG=${NPM_DIR}/npmrc\
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    SHELL=/bin/bash \
    NB_USER=${NB_USER} \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    JUPYTER_ENABLE_LAB=yes \
    PYTHON_VERSION=${PYTHON_VERSION} \
    DOCKER_USER=${DOCKER_USER} \
    DOCKER_REPO=${DOCKER_REPO} \
    VERSION=${VERSION} \
    USER=${NB_USER} \
    HOME=/home/${NB_USER} \
    REPO_DIR=/home/${NB_USER} \
    XDG_CACHE_HOME=/home/${NB_USER}/.cache \
    MAKE_OPTS="-j8" \
    CONFIGURE_OPTS="--enable-shared --enable-optimizations --with-computed-gotos" \
    NPY_USE_BLAS_ILP64=1 \
    MAX_CONCURRENCY=8

WORKDIR ${HOME}
RUN ln -s ${NODE_PATH}  ${HOME}/node_modules

RUN curl https://pyenv.run | bash

COPY entrypoint /usr/local/bin/entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint"]

CMD ["jupyter", "notebook", "--ip", "0.0.0.0"]
EXPOSE 8888

FROM ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION} as devel
ARG PYTHON_VERSION

RUN sudo apk add --update alpine-sdk expat-dev openssl-dev zlib-dev ncurses-dev bzip2-dev xz-dev sqlite-dev libffi-dev linux-headers readline-dev pixman-dev cairo-dev pango-dev openjpeg-dev librsvg-dev giflib-dev libpng-dev openblas-dev lapack-dev gfortran libxml2-dev zeromq-dev gnupg tar xz expat-dev gdbm-dev libnsl-dev libtirpc-dev pax-utils util-linux-dev xz-dev zlib-dev libjpeg-turbo-dev tiff-dev libwebp-dev libimagequant-dev lcms2-dev 

WORKDIR ${PYENV_ROOT}
RUN pyenv install -v ${PYTHON_VERSION} && pyenv global ${PYTHON_VERSION}
RUN pip install -U  pip -U setuptools -U wheel 

WORKDIR ${NPM_DIR}
COPY --chown=${NB_USER} package.json  ${NPM_DIR}/package.json
RUN npm install --verbose -dd --prefix ${NPM_DIR}
RUN npm cache clean --force

WORKDIR ${PYENV_ROOT}
COPY --chown=${NB_USER} requirements-base.txt requirements-base.txt 
RUN pip install -vv -r requirements-base.txt 
RUN jupyter serverextension enable nbgitpuller --sys-prefix && jupyter serverextension enable --sys-prefix jupyter_server_proxy && jupyter labextension install @jupyterlab/server-proxy && jupyter lab clean -y && npm cache clean --force
COPY --chown=${NB_USER} requirements-extra.txt requirements-extra.txt
RUN pip install -vv -r requirements-extra.txt

WORKDIR ${HOME}

FROM ${DOCKER_USER}/${DOCKER_REPO}:base-${VERSION}  as deploy

COPY --chown=${NB_USER} --from=devel ${ENV_ROOT} ${ENV_ROOT}
RUN sudo apk add --no-cache neofetch 

