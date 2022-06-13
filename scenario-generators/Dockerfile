# Base Dockerfile
#
# This image is used as a base image for both production and development builds.
# It's built separately to speed up build times.

FROM python:3

WORKDIR /scenario-generators
COPY pyproject.toml poetry.lock /scenario-generators

RUN apt-get update && \
    pip3 install poetry==1.1.12 && \
    poetry install && \
    rm -rf /var/lib/apt/lists/*

COPY . /scenario-generators

ENTRYPOINT ["poetry", "run", "python"]
