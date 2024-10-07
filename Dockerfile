FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
RUN apt-get update && apt-get install -y \
    wget \
    lsb-release

# Reference: https://cvmfs.readthedocs.io/en/stable/cpt-repo.html

# Add CVMFS repository
RUN cd /tmp \
    && wget https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release_4.3-1_all.deb \
    && echo "7fa925c8a7d312c486fac6acb4ceff546dec235f83f0de4c836cab8a09842279 cvmfs-release_4.3-1_all.deb" | sha256sum -c \
    && dpkg -i cvmfs-release_4.3-1_all.deb \
    && rm cvmfs-release_4.3-1_all.deb

# Install CVMFS
RUN apt-get update && apt-get install -y \
    cvmfs \
    cvmfs-server \
    s3cmd

# TODO: remove this after testing
RUN apt-get update && apt-get install -y \
    vim
