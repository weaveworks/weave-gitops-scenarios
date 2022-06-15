# Base Dockerfile
#
# This image is used as a base image for both production and development builds.
# It's built separately to speed up build times.

FROM python:3


RUN echo 'alias ls="ls --color=auto"\nalias l="ls -lah"' >> ~/.bashrc

WORKDIR /app

COPY pyproject.toml poetry.lock .

RUN apt-get update && \
    pip3 install poetry==1.1.12 && \
    poetry install && \
    rm -rf /var/lib/apt/lists/*

COPY scenario-generators/ scenario-generators/

ENTRYPOINT ["poetry", "run", "python", "-m"]
