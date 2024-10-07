FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget \
    lsb-release

# Reference: https://cvmfs.readthedocs.io/en/stable/cpt-repo.html

# Add CernVM-FS repository
RUN cd /tmp \
    && wget https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release_4.3-1_all.deb \
    && echo "7fa925c8a7d312c486fac6acb4ceff546dec235f83f0de4c836cab8a09842279 cvmfs-release_4.3-1_all.deb" | sha256sum -c \
    && dpkg -i cvmfs-release_4.3-1_all.deb \
    && rm cvmfs-release_4.3-1_all.deb

# Install CernVM-FS and CernVM-FS server
RUN apt-get update && apt-get install -y \
    cvmfs \
    cvmfs-server

