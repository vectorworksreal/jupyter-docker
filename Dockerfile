# Start from NVIDIA CUDA base image with Ubuntu
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Install Python and basic utilities
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    git \
    curl \
    wget \
    gcc \
    g++ \
    make \
    zsh \
    fonts-powerline \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user and setup workspace
ENV NB_USER=jupyter
ENV NB_UID=1000
RUN mkdir -p /workspace && \
    useradd -m -s /usr/bin/zsh -N -u ${NB_UID} ${NB_USER} && \
    echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${NB_USER} && \
    chmod 0440 /etc/sudoers.d/${NB_USER} && \
    chown -R ${NB_USER} /workspace && \
    # Create .local directory for user-specific package installations
    mkdir -p /home/${NB_USER}/.local && \
    chown -R ${NB_USER}:root /home/${NB_USER}/.local

# Switch to the non-root user for oh-my-zsh installation
USER ${NB_UID}

# Install oh-my-zsh and plugins
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Configure zsh
COPY <<-"EOF" /home/${NB_USER}/.zshrc
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
export TERM=xterm-256color

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Custom aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias pip='pip3'
alias python='python3'

# Better directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# Custom prompt settings
PROMPT_EOL_MARK=''
EOF

# Switch back to root for remaining installations
USER root

# Install basic Python packages globally
RUN pip3 install --no-cache-dir \
    jupyter \
    notebook \
    jupyterlab==4.0.9 \
    httpx==0.24.1 \
    numpy \
    pandas \
    matplotlib \
    seaborn \
    scikit-learn \
    transformers \
    opencv-python \
    pillow \
    pytest \
    ipywidgets \
    tqdm \
    requests \
    beautifulsoup4 \
    fastapi \
    python-dotenv

# Install PyTorch with CUDA support
RUN pip3 install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Switch to jupyter user for configuration
USER ${NB_UID}

# Set PATH to include .local/bin
ENV PATH="/home/${NB_USER}/.local/bin:${PATH}"

# Generate Jupyter config
RUN mkdir -p /home/${NB_USER}/.jupyter && \
    jupyter notebook --generate-config && \
    echo "c.NotebookApp.allow_origin = '*'" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.ip = '0.0.0.0'" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.allow_remote_access = True" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.open_browser = False" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.notebook_dir = '/workspace'" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.token = ''" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py && \
    echo "c.NotebookApp.password = ''" >> /home/${NB_USER}/.jupyter/jupyter_notebook_config.py

# Expose the Jupyter port
EXPOSE 8888

# Set the working directory to RunPod's default workspace path
WORKDIR /workspace

# Command to run Jupyter notebook with specific configurations
CMD ["jupyter", "notebook", "--NotebookApp.token=''", "--NotebookApp.password=''", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
