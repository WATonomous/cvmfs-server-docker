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
docker compose run --service-ports cvmfs-server

# create bucket and make the bucket publicly readable
s3cmd -c /workspace/s3cfg mb s3://cvmfs
s3cmd -c /workspace/s3cfg setpolicy /workspace/minio-policy.json s3://cvmfs

# create the cvmfs repository
# cvmfs_server mkfs -s /workspace/s3.conf -w http://minio:9000/cvmfs cvmfs.cluster.watonomous.ca
cvmfs_server mkfs -s /workspace/s3.conf -w http://minio:9000/cvmfs cvmfs-server.example.local

# a2enmod headers expires proxy proxy_http
# service apache2 start
# cvmfs_server mkfs cvmfs-server.example.local
```

Make changes to the CVMFS repository:

```bash
# In the cvmfs-server container
cvmfs_server transaction

# Make changes to the repository
# echo "test" > /cvmfs/cvmfs.cluster.watonomous.ca/test.txt
echo "test" > /cvmfs/cvmfs-server.example.local/test.txt

# Publish the changes
cvmfs_server publish
```


## CVMFS client

```bash
docker compose down cvmfs-client --remove-orphans; docker compose run --entrypoint sh cvmfs-client

# This is required. Otherwise we get "CernVM-FS: loading Fuse module... Failed to initialize root file catalog (16 - file catalog failure)"
cat <<EOF > /etc/cvmfs/keys/cvmfs-server.example.local.pub 
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAzsZ5AUhDqfzjtlaOA3Rc
xt6hBO6OS1tUvTtCHNIuLZmro/Ga6bflgECc64p/Hn2nIxRQuQkgJ6O8+YU0WFJr
rnDz1R3qoh0T+Y4PSbPuZbenjVKJbW8TQ3nPmCukL+bd4G5MmY3qM+7HXovBKPQN
h0SIxmzbr93HnQ38hgy+5HDzRH5LDk0+0muBlv9wJBm6xW5iXhiq+0qmO3Qa3+Z3
+gqULKlUBVbIlOca4ZE3RbzUrGDBbnrEc0PZx39ykhqiAe7nIQGXW4q0aTJSpu5B
mTc9WvviQuwNkz1Zfz5JLF5aUn+1LY1XEB2pxqtlchAUJRfNdhtL7hABnxWxHpda
2wIDAQAB
-----END PUBLIC KEY-----
EOF

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

## References

- [Creating a Repository (Stratum 0)](https://cvmfs.readthedocs.io/en/stable/cpt-repo.html)
- [Stratum 0 and client tutorial](https://cvmfs-contrib.github.io/cvmfs-tutorial-2021/02_stratum0_client/)