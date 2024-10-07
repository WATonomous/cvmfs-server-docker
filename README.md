# cvmfs-server-docker

A Dockerized CVMFS stratum 0 server with a MinIO backend.

> [!NOTE]
> This is a work in progress and should not be used in production. The roadmap is outlined in the [TODO](#TODO) section.

## Getting started

Initialize the CVMFS repository:

```bash
# start minio
docker compose up minio


# start the cvmfs server
docker compose down cvmfs-server --remove-orphans; docker compose run --service-ports cvmfs-server

# create bucket and make the bucket publicly readable
s3cmd -c /workspace/s3cfg mb s3://cvmfs
s3cmd -c /workspace/s3cfg setpolicy /workspace/minio-policy.json s3://cvmfs

# create the cvmfs repository
# cvmfs_server mkfs -s /workspace/s3.conf -w http://minio:9000/cvmfs cvmfs.cluster.watonomous.ca
cvmfs_server mkfs -s /workspace/s3.conf -w http://minio:9000/cvmfs cvmfs-server.example.local

# apache2 approach (alternative to S3)
mkdir /srv/cvmfs
ln -s /srv/cvmfs /var/www/cvmfs
a2enmod headers expires proxy proxy_http
service apache2 start
cvmfs_server mkfs cvmfs-server.example.local
```

Make changes to the CVMFS repository:

```bash
# In the cvmfs-server container
cvmfs_server transaction

# Make changes to the repository
# echo "test" > /cvmfs/cvmfs.cluster.watonomous.ca/test.txt
echo "test" > /cvmfs/cvmfs-server.example.local/test.txt
dd if=/dev/random of=/cvmfs/cvmfs-server.example.local/test5 bs=1M count=1024
dd if=/dev/zero of=/cvmfs/cvmfs-server.example.local/test6 bs=1M count=1024

# Publish the changes
cvmfs_server publish
```

Useful commands:

```bash
# list files in the repository
s3cmd -c /workspace/s3cfg ls s3://cvmfs/cvmfs-server.example.local/

# view disk usage
s3cmd -c /workspace/s3cfg du -H 's3://cvmfs/cvmfs-server.example.local/data/'

# check the repository for consistency issues
cvmfs_server check

# delete files from the repository
s3cmd -c /workspace/s3cfg del --recursive s3://cvmfs/cvmfs-server.example.local/data

# generate graft file with chunk size of 2048M
cvmfs_swissknife graft -i /cvmfs/cvmfs-server.example.local/test5 -c 2048
```


## CVMFS client

```bash
docker compose down cvmfs-client --remove-orphans; docker compose run --entrypoint sh cvmfs-client

# This is required. Otherwise we get "CernVM-FS: loading Fuse module... Failed to initialize root file catalog (16 - file catalog failure)"
# This is obtained from the host.
cat <<EOF > /etc/cvmfs/keys/cvmfs-server.example.local.pub 
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2UcOiQM3HGdxD1GE62l6
7tgeD5ZbME4o+7zsGknzuMU/QABw/huRi/gk9yUmhSoMQytU+DJbs++6/KfWHK/W
TclMAbHZpPjPD9z7IVDWy6lLZ0SWXJq61ImA7VHjWg0fjtAygjGMGrA48B+YbS55
lckghsZkRR5/Vg4tFGJqbr18HpY7qqh7PaCYKUlkflRPYokZuqPTmhqNHUfsGqNM
y8dOSeIqe75xXDmBAHG3XJydHBJK/1wh1mARJlMJkDu/uQ5qynv5N5+piiI0jLC7
S10ZtRodlI5DGnolRzTTv5fy7oXk+CUif8cQ7IkIB0KnuJw8gCJeyvwZJ+mKRGVf
gwIDAQAB
-----END PUBLIC KEY-----
EOF


# apache2
cat <<EOF > /etc/cvmfs/config.d/cvmfs-server.example.local.conf
# For some reason we can't use @fprn@ here. The client doesn't appear to do the substitution.
CVMFS_SERVER_URL=http://cvmfs-server.example.local/cvmfs/cvmfs-server.example.local
CVMFS_KEYS_DIR="/etc/cvmfs/keys"
# Makes the client check for updates more frequently. In minutes.
CVMFS_MAX_TTL=1
# Required. Otherwise we get "failed to discover HTTP proxy servers (23 - proxy auto-discovery failed)" on our custom cvmfs-server.
CVMFS_HTTP_PROXY=DIRECT
EOF

# s3
cat <<EOF > /etc/cvmfs/config.d/cvmfs-server.example.local.conf
CVMFS_SERVER_URL=http://minio:9000/cvmfs/@fprn@
CVMFS_KEYS_DIR="/etc/cvmfs/keys"
# Makes the client check for updates more frequently. In minutes.
CVMFS_MAX_TTL=1
# Required. Otherwise we get "failed to discover HTTP proxy servers (23 - proxy auto-discovery failed)" on our custom cvmfs-server.
CVMFS_HTTP_PROXY=DIRECT
EOF

/usr/bin/mount_cvmfs.sh
```

## TODO

- [ ] Figure out how to access the repo as a client
- [ ] Automate transactions for programmatic changes via CI (potentially with [grafting](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html#grafting-files) support)
- [ ] Figure out the whitelist signing procedure (needs to be done every 30 days)
- [ ] Aggregate keys to a subdir of `/etc/cvmfs/keys/` using the `CVMFS_KEYS_DIR` setting. Distribute public keys to clients.
- [ ] Configure `CVMFS_SERVER_URL` on the server as well.
- [ ] Turn on garbage collection in /etc/cvmfs/repositories.d/cvmfs-server.example.local/server.conf
- [ ] Consider CI strategy - upload caches to S3, graft the files. Then use cvmfs on the client with fallback to direct S3 access when cvmfs has not been propagated?
- [x] Experiment with server with apache2 instead of minio.
- [ ] Test ephemeral data storage - only persist keys and configuration. Wipe data on restart.

## References

- [Creating a Repository (Stratum 0)](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html)
- [Stratum 0 and client tutorial](https://cvmfs-contrib.github.io/cvmfs-tutorial-2021/02_stratum0_client/)