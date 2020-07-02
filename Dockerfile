FROM ubuntu:20.04

LABEL maintainer="Petter Olsson <petter@dominodatalab.com>"

# Utilities required by Domino
ENV DEBIAN_FRONTEND noninteractive

# Create a Ubuntu User
RUN \
  groupadd -g 12574 ubuntu && \
  useradd -u 12574 -g 12574 -m -N -s /bin/bash ubuntu && \
  apt-get update -y && \
  apt-get -y install software-properties-common apt-utils && \
  apt-get -y upgrade && \
  # CONFIGURE locales
  apt-get install -y locales && \
  locale-gen en_US.UTF-8 && \
  dpkg-reconfigure locales && \
  # INSTALL common
  apt-get -y install build-essential wget sudo curl apt-utils git vim python3-pip -y && \
  # Install jdk
  apt-get install openjdk-8-jdk -y && \
  update-alternatives --config java && \
  echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /home/ubuntu/.domino-defaults && \
  # Add SSH start script for ssh'ing to run container in Domino <v4.0
  apt-get install -y openssh-server && \
  mkdir -p /scripts && \
  printf "#!/bin/bash\\nservice ssh start\\n" > /scripts/start-ssh && \
  chmod +x /scripts/start-ssh && \
  echo 'export PYTHONIOENCODING=utf-8' >> /home/ubuntu/.domino-defaults && \
  echo 'export LANG=en_US.UTF-8' >> /home/ubuntu/.domino-defaults && \
  echo 'export JOBLIB_TEMP_FOLDER=/tmp' >> /home/ubuntu/.domino-defaults && \
  echo 'export LC_ALL=en_US.UTF-8' >> /home/ubuntu/.domino-defaults && \
  locale-gen en_US.UTF-8

ENV LANG en_US.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# Install R
ENV R_BASE_VERSION 4.0.2
RUN \ 
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 && \
    add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu focal-cran40/' && \
    apt-get update -y && \
    apt-get install \ 
    r-base=${R_BASE_VERSION}-* \
    r-base-dev=${R_BASE_VERSION}-* -y && \
# INSTALL R packages required by Domino
    R -e 'options(repos=structure(c(CRAN="http://cran.us.r-project.org"))); install.packages(c( "plumber","yaml", "shiny"))' && \
    chown -R ubuntu:ubuntu /usr/local/lib/R/site-library

# Install Python 3.8 and Miniconda
# https://repo.continuum.io/miniconda
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH 
ENV MINICONDA_VERSION py38_4.8.2     
ENV MINICONDA_MD5 cbda751e713b5a95f187ae70b509403f
ENV PYTHON_VER 3.8
# Set env variables so they are available in Domino runs/workspaces
RUN \
    echo 'export CONDA_DIR=/opt/conda' >> /home/ubuntu/.domino-defaults && \
    echo 'export PATH=$CONDA_DIR/bin:$PATH' >> /home/ubuntu/.domino-defaults  && \
    echo 'export PATH=/home/ubuntu/.local/bin:$PATH' >> /home/ubuntu/.domino-defaults && \
    cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "${MINICONDA_MD5} *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    conda install python=${PYTHON_VER} && \
# Make conda folder permissioned for ubuntu user
    chown ubuntu:ubuntu -R $CONDA_DIR && \
# Use Mini-conda's pip
    ln -s $CONDA_DIR/bin/pip /usr/bin/pip && \
    pip install --upgrade pip && \
# Use Mini-conda's python   
    ln -s $CONDA_DIR/bin/python /usr/local/bin/python && \
    ln -s $CONDA_DIR/anaconda/bin/python /usr/local/bin/python3  && \
# Set permissions
    chown -R ubuntu:ubuntu  $CONDA_DIR && \
# Install Domino Dependencies ####  
   $CONDA_DIR/bin/conda install -c conda-forge uWSGI==2.0.18 && \
# Packages used for model APIs
    pip install Flask==1.0.2 Flask-Compress==1.4.0 Flask-Cors==3.0.6 jsonify==0.5

# Installing Notebooks,Workspaces,IDEs,etc ####
# Clone in workspaces install scripts
# Add workspace configuration files
# Start by adding some fixes
RUN echo "Set disable_coredump false" >> /etc/sudo.conf
RUN APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
RUN apt-get remove -y openssl
RUN \
    cd /tmp && \
    wget -q --no-check-certificate https://github.com/dominopetter/workspaces/archive/1.0.9.zip && \
    unzip 1.0.9.zip && \
    cp -Rf workspaces-1.0.9/. /var/opt/workspaces && \
    rm -rf /var/opt/workspaces/workspace-logos && rm -rf /tmp/workspaces-1.0.9
# Add update .Rprofile with Domino customizations
RUN \
    mv /var/opt/workspaces/rstudio/.Rprofile /home/ubuntu/.Rprofile && \
    chown ubuntu:ubuntu /home/ubuntu/.Rprofile && \
# Install Rstudio from workspaces
    chmod +x /var/opt/workspaces/rstudio/install  && \
    /var/opt/workspaces/rstudio/install && \
# Install Jupyterlab from workspaces
    chmod +x /var/opt/workspaces/Jupyterlab/install && \
    /var/opt/workspaces/Jupyterlab/install && \
# Install Jupyter from workspaces
    chmod +x /var/opt/workspaces/jupyter/install && \
    /var/opt/workspaces/jupyter/install && \
# Required for VSCode
    apt-get update && \
    apt-get install -y Node.js npm node-gyp nodejs && \
    pip install python-language-server autopep8 flake8 && \
    rm -rf /var/lib/apt/lists/* && \
# Install vscode from workspaces
    chmod +x /var/opt/workspaces/vscode/install && \
    /var/opt/workspaces/vscode/install && \
# Fix permissions so notebooks start
   chown -R ubuntu:ubuntu /home/ubuntu/.local/

# Provide Sudo in container
RUN echo "ubuntu    ALL=NOPASSWD: ALL" >> /etc/sudoers

# Clean up
RUN \
  find /opt/conda/ -follow -type f -name '*.a' -delete && \
  find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
  $CONDA_DIR/bin/conda clean -afy && \
  apt-get clean && apt-get autoremove -y && \
  rm --force --recursive /var/lib/apt/lists/* && \
  rm --force --recursive /tmp/*
