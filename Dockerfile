# syntax=docker/dockerfile:1.4
ARG BASE_OS="bitnami/minideb"
ARG OS_VERSION="bookworm"

# Base system stage
FROM ${BASE_OS}:${OS_VERSION} AS base

ARG USERNAME=developer
ARG USER_UID=1001
ARG USER_GID=${USER_UID}

# Configure environment
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1\
    PATH="/home/${USERNAME}/.local/bin:${PATH}"

# Install system dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    install_packages --no-install-recommends \
        bash \
        git \
        nodejs \
        npm \
        python3 \
        python3-pip \
        curl \
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
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid "${USER_GID}" "${USERNAME}" && \
    useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}" && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" && \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"

# Build tools stage
FROM base AS build-tools

ARG SETUP_CPP_VERSION="1.7.0"

# Install development tools
RUN npm install -g setup-cpp@${SETUP_CPP_VERSION} && \
    NODE_OPTIONS="--enable-source-maps" \
    setup-cpp \
        --nala false \
        --compiler llvm \
        --cmake true \
        --ninja true \
        --task true \
        --vcpkg true \
        --conan false \
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
        --ccache true && \
    npm cache clean --force

# Final image stage
FROM base AS dev-environment

ARG PYTHON_VERSION="3.12.1"
ARG USERNAME=developer

# Switch to non-root user
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Configure environment variables
ENV PYENV_ROOT="/home/${USERNAME}/.pyenv" 
ENV PATH="${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:${PATH}"

# Install pyenv and Python version
RUN curl -fsSL https://pyenv.run | bash && \
    { echo; \
      echo 'export PYENV_ROOT="$HOME/.pyenv"'; \
      echo 'export PATH="$PYENV_ROOT/bin:$PATH"'; \
      echo 'eval "$(pyenv init --path)"'; \
      echo 'eval "$(pyenv virtualenv-init -)"'; } >> ~/.bashrc && \
    eval "$(pyenv init --path)" && \
    pyenv install "${PYTHON_VERSION}" && \
    pyenv global "${PYTHON_VERSION}" && \
    pyenv rehash && \
    python -m pip install --upgrade pip setuptools wheel &&\
    python -m pip install --user pipx && \
    python -m pipx ensurepath


# Install user tools with pipx
RUN pipx install conan &&\
    pipx ensurepath 

# Configure Conan using external configuration files
RUN mkdir -p ~/.conan/profiles && \
    conan profile detect --name=default && \
    printf "[settings]\nos=Linux\narch=x86_64\ncompiler=clang\ncompiler.version=14\n" \
           "compiler.cppstd=23\ncompiler.libcxx=libstdc++23\nbuild_type=Release" \
           > ~/.conan/profiles/default && \
    printf "[general]\nrevisions_enabled=1" > ~/.conan/conan.conf

# Install and configure zsh
RUN sudo install_packages zsh && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k && \
    { \
    echo 'export TERM="xterm-256color"'; \
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"'; \
    echo 'DISABLE_UPDATE_PROMPT=true'; \
    echo 'plugins=(git python docker docker-compose virtualenv)'; \
    echo 'export POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true'; \
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'; \
    } >> ~/.zshrc

# Final setup
COPY <<-"EOT" /home/${USERNAME}/.bashrc
export PS1="\[\033[1;32m\]\u@dev-container\[\033[0m\]:\w\$ "
source ~/.profile
EOT

# Default command
CMD ["zsh"]

