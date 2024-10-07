# cvmfs-server-docker

A Dockerized CVMFS stratum 0 server with a MinIO backend.

> [!NOTE]
> This is a work in progress and should not be used in production. The roadmap is outlined in the [TODO](#TODO) section.

## Getting started

Initialize the CVMFS repository:

```bash
# 1. start minio
docker compose up minio
# 2. (MANUAL) make the cvmfs bucket publicly readable (e.g. via the web interface)

# 3. start the cvmfs server
docker compose run cvmfs-server

# 4. create the cvmfs repository
cvmfs_server mkfs -s /workspace/s3.conf -w http://minio:9000/cvmfs cvmfs.cluster.watonomous.ca
```

Make changes to the CVMFS repository:

```bash
# In the cvmfs-server container
cvmfs_server transaction

# Make changes to the repository
echo "test" > /cvmfs/cvmfs.cluster.watonomous.ca/test.txt

# Publish the changes
cvmfs_server publish
```

## TODO

- [ ] Figure out how to access the repo as a client
- [ ] Automate transactions for programmatic changes via CI (potentially with [grafting](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html#grafting-files) support)

## References

- [Creating a Repository (Stratum 0)](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html)
