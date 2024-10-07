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

# make the public key available for clients
mkdir /var/www/html/cvmfs-meta
cp /etc/cvmfs/keys/cvmfs-server.example.local.pub /var/www/html/cvmfs-meta
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

# apache2
# The public key is required. Otherwise we get "CernVM-FS: loading Fuse module... Failed to initialize root file catalog (16 - file catalog failure)"
wget cvmfs-server.example.local/cvmfs-meta/cvmfs-server.example.local.pub -O /etc/cvmfs/keys/cvmfs-server.example.local.pub
cat <<EOF > /etc/cvmfs/config.d/cvmfs-server.example.local.conf
# For some reason we can't use @fprn@ here. The client doesn't appear to do the substitution.
CVMFS_SERVER_URL=http://cvmfs-server.example.local/cvmfs/cvmfs-server.example.local
CVMFS_KEYS_DIR=/etc/cvmfs/keys/
# Makes the client check for updates more frequently. In minutes.
CVMFS_MAX_TTL=1
# Required. Otherwise we get "failed to discover HTTP proxy servers (23 - proxy auto-discovery failed)" on our custom cvmfs-server.
CVMFS_HTTP_PROXY=DIRECT
EOF

# s3
cat <<EOF > /etc/cvmfs/config.d/cvmfs-server.example.local.conf
CVMFS_SERVER_URL=http://minio:9000/cvmfs/@fprn@
CVMFS_KEYS_DIR=/etc/cvmfs/keys/
# Makes the client check for updates more frequently. In minutes.
CVMFS_MAX_TTL=1
# Required. Otherwise we get "failed to discover HTTP proxy servers (23 - proxy auto-discovery failed)" on our custom cvmfs-server.
CVMFS_HTTP_PROXY=DIRECT
EOF

/usr/bin/mount_cvmfs.sh
```

## Offline mode and recovery

When the cvmfs server goes down, the client will atomatically switch to offline mode and continue to serve files from the cache.
With `CVMFS_MAX_TTL=1` it appears that the client will notice the server going down within a minute and notice the server coming back up in around 3 minutes.
I'm currently not sure which parameter determines how often the client checks for the server being back up.

`/var/log/cvmfs.log` with comments:

```
# server going down at "Mon Oct  7 18:57:44 UTC 2024"

Mon Oct  7 18:58:29 2024 (cvmfs-server.example.local) failed to download repository manifest (4 - failed to resolve host address)
Mon Oct  7 18:58:29 2024 (cvmfs-server.example.local) warning, could not apply updated catalog revision, entering offline mode

# server coming back up at "Mon Oct  7 18:58:59 UTC 2024"

Mon Oct  7 19:01:29 2024 (cvmfs-server.example.local) recovered from offline mode
Mon Oct  7 19:01:34 2024 (cvmfs-server.example.local) switched to catalog revision 1
```

Relevant documentation can be found at:
- https://cvmfs.readthedocs.io/en/stable/cpt-configure.html


## Quirks

On a fresh start of dockerd, the `cvmfs_server mkfs` command seems to complete properly:

```
> docker compose down cvmfs-server --remove-orphans; docker compose run --service-ports cvmfs-server
root@cvmfs-server:/# mkdir /srv/cvmfs
ln -s /srv/cvmfs /var/www/cvmfs
a2enmod headers expires proxy proxy_http
service apache2 start
cvmfs_server mkfs cvmfs-server.example.local

Enabling module headers.
Enabling module expires.
Enabling module proxy.
Considering dependency proxy for proxy_http:
Module proxy already enabled
Enabling module proxy_http.
To activate the new configuration, you need to run:
  service apache2 restart
 * Starting Apache httpd web server apache2                                                                                                                                                                                                                      * 
Owner of cvmfs-server.example.local [root]: 
Creating Configuration Files... done
Creating CernVM-FS Master Key and Self-Signed Certificate... done
Creating CernVM-FS Server Infrastructure... done
Creating Backend Storage... done
Signing 30 day whitelist with master key... done
Creating Initial Repository... done
Mounting CernVM-FS Storage... (overlayfs) done
Allowing Replication of this Repository... done
Initial commit... New CernVM-FS repository for cvmfs-server.example.local
Updating global JSON information... done

Before you can install anything, call `cvmfs_server transaction`
to enable write access on your repository. Then install your
software in /cvmfs/cvmfs-server.example.local as user root.
Once you're happy, publish using `cvmfs_server publish`

For client configuration, have a look at 'cvmfs_server info'

If you go for production, backup your masterkey from /etc/cvmfs/keys/!
root@cvmfs-server:/# echo $?
0
```

However, on a subsequent run (even after `docker system prune -a`), the `cvmfs_server mkfs` command exits with error. But everything seems to be working fine:

```
root@cvmfs-server:/# mkdir /srv/cvmfs
ln -s /srv/cvmfs /var/www/cvmfs
a2enmod headers expires proxy proxy_http
service apache2 start
cvmfs_server mkfs cvmfs-server.example.local
Enabling module headers.
Enabling module expires.
Enabling module proxy.
Considering dependency proxy for proxy_http:
Module proxy already enabled
Enabling module proxy_http.
To activate the new configuration, you need to run:
  service apache2 restart
 * Starting Apache httpd web server apache2                                                                                                                                                                                                                      * 
Owner of cvmfs-server.example.local [root]: 
Creating Configuration Files... done
Creating CernVM-FS Master Key and Self-Signed Certificate... done
Creating CernVM-FS Server Infrastructure... done
Creating Backend Storage... done
Signing 30 day whitelist with master key... done
Creating Initial Repository... done
Mounting CernVM-FS Storage... (overlayfs) done
Allowing Replication of this Repository... done
cvmfs-server.example.local is not based on the newest published revision
fail! (health check after mount)
```

EDIT: this is due to `/tmp/cvmfs-spool` not cleaned up. Simply removing the directory fixes the issue.

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
- [Server Spool Area of a Repository (Stratum0)](https://cvmfs.readthedocs.io/en/stable/apx-serverinfra.html#server-spool-area-of-a-repository-stratum0)