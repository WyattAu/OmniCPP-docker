# syntax=docker/dockerfile:1.4
ARG BASE_OS="bitnami/minideb"

# Tag of the base OS image
ARG OS_VERSION="bookworm"

# Image with layers as used by all succeeding steps
FROM ${BASE_OS}:${OS_VERSION} AS base

ARG SETUP_CPP_VERSION="1.7.0"
ARG PYTHON_VERSION="3.12.1"
ARG USERNAME=developer
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# Configure environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN install_packages --no-install-recommends \
        bash \
        git \
        nodejs \
        npm \
        python3 \
        python3-pip \
        curl \
        pipx \
        gdb \
        sudo \
        wget \
        libffi-dev \
        libsqlite3-dev \
        liblzma-dev \
        libreadline-dev \
        libtk-img-dev \
        libssl-dev \
        libbz2-dev \
        libwayland-bin \
        libwayland-dev \
        libxcb-util-dev \
        libxkbcommon-dev \
        libxkbcommon-x11-dev \
        libxrandr-dev \
        libxcursor-dev \
        libcurses-ocaml-dev \
        libxi-dev \
        libxinerama-dev \
        libgl1-mesa-dev \
        libx11-xcb-dev \
        libfontenc-dev \
        libice-dev \
        libsm-dev \
        libxau-dev \
        libxcomposite-dev \
        libxdamage-dev \
        libxkbfile-dev \
        libxmuu-dev \
        libxres-dev \
        libxtst-dev \
        libxv-dev \
        libxxf86vm-dev \
        libxcb-glx0-dev \
        libxcb-render0-dev \
        libxcb-render-util0-dev \
        libxcb-icccm4-dev \
        libxcb-image0-dev \
        libxcb-keysyms1-dev \
        libxcb-randr0-dev \
        libxcb-shape0-dev \
        libxcb-sync-dev \
        libxcb-xfixes0-dev \
        libxcb-xinerama0-dev \
        libxcb-dri3-dev \
        libxcb-cursor-dev \
        libxcb-dri2-0-dev \
        libxcb-present-dev \
        libxcb-composite0-dev \
        libxcb-ewmh-dev \
        libxcb-res0-dev \
        libxaw7-dev \
        libglfw3-dev && \
    rm -rf /var/lib/apt/lists/* &&\
    apt-get clean


RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}    

# Install setup-cpp and configure tools
RUN npm install -g setup-cpp@${SETUP_CPP_VERSION} &&\
    NODE_OPTIONS="--enable-source-maps" \
    setup-cpp \
        --nala false \
        --compiler llvm \
        --cmake true \
        --ninja true \
        --task true \
        --vcpkg true \
        --conan true \
        --make true \
        --clang-tidy true \
        --clang-format true \
        --cppcheck true \
        --cpplint true \
        --cmakelang true \
        --cmake-format true \
        --cmake-lint \
        --gcovr true \
        --doxygen true \
        --ccache true &&\
    npm cache clean --force

# Configure Conan
RUN conan profile detect --force && \
    conan profile update settings.compiler.cppstd=23 default && \
    conan profile update settings.compiler.libcxx=libstdc++11 default && \
    conan config set general.revisions_enabled=1


RUN curl -fsSL https://pyenv.run | bash && \
    { echo; \
      echo 'export PYENV_ROOT="$HOME/.pyenv"'; \
      echo 'export PATH="$PYENV_ROOT/bin:$PATH"'; \
      echo 'eval "$(pyenv init -)"'; \
      echo 'eval "$(pyenv virtualenv-init -)"'; } >> /etc/profile.d/pyenv.sh && \
    export PYENV_ROOT="/root/.pyenv" && \
    export PATH="$PYENV_ROOT/bin:$PATH" && \
    pyenv install ${PYTHON_VERSION} && \
    pyenv global ${PYTHON_VERSION} && \
    pyenv rehash

# Clean temporary files as root
RUN rm -rf /tmp/* && \
    find /tmp -mindepth 1 -delete || true

# Switch to developer user
USER $USERNAME
WORKDIR /home/$USERNAME

# Configure final environment variables
ENV PYENV_ROOT="/home/$USERNAME/.pyenv"
ENV PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:/home/$USERNAME/.local/bin:$PATH"

RUN find /tmp -mindepth 1 -user developer -delete || true

RUN pipx install pip && \
    pipx install wheel && \
    pipx ensurepath --force && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Final environment setup
RUN echo 'export PS1="\[\033[1;32m\]\u@dev-container\[\033[0m\]:\w\$ "' >> ~/.bashrc

ENTRYPOINT ["/bin/bash"]
