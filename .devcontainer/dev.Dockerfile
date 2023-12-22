## For convenience in VSCode...
FROM mcr.microsoft.com/devcontainers/base:bookworm


## Downloading OpenSCAD dependencies and copying binaries
## Adapted from https://github.com/openscad/docker-openscad/blob/main/openscad/bookworm/Dockerfile 
RUN apt-get update

RUN apt-get -y full-upgrade

RUN apt-get install -y --no-install-recommends \
	libcairo2 libdouble-conversion3 libxml2 lib3mf1 libzip4 libharfbuzz0b \
	libboost-thread1.74.0 libboost-program-options1.74.0 libboost-filesystem1.74.0 \
	libboost-regex1.74.0 libmpfr6 libqscintilla2-qt5-15 \
	libqt5multimedia5 libqt5concurrent5 libtbb12 libglu1-mesa \
	libglew2.2 xvfb xauth

RUN apt-get clean

WORKDIR /usr/local

COPY --from=openscad/openscad:dev.2023-12-18 /usr/local/ .


## Customization
ARG USER=vscode

USER $USER

# OpenSCAD parameters (hiding console...)
COPY --chown=$USER:$USER OpenSCAD.conf /home/$USER/.config/OpenSCAD/

# OpenSCAD librairies installation
RUN mkdir -p /home/$USER/.local/share/OpenSCAD/libraries/
WORKDIR /home/$USER/.local/share/OpenSCAD/libraries/

RUN git clone https://github.com/BelfrySCAD/BOSL2.git