# IPFS Upload
Simple IPFS remote pinning service and
HTTP upload provider.

Currently, it only supports Postgres and LDAP
as backends. LDAP is used to login while Postgres
is used to store information about pins and access tokens
used by tools.

In addition to providing a remote pinning endpoint
at /api, you can also POST uploads directly to the
root `/` with an access token and recieve a URL back:
```shell
$ curl -H "Authorization: Bearer ..." -F file=@file https://u.unix.dog/
https://unix.dog/ipfs/Qm...
```

## Setup
To setup this service locally, you will need:
- PostgreSQL
- LDAP service with password auth
- IPFS node with RPC API (Kubo)

Copy the config ipfs_upload.default.yml to
ipfs_upload.yml, and edit the config appropriately.
Then use hypnotoad or morbo to run `script/IpfsUpload`.
Log in, generate tokens, and point your IPFS remote pinning
to /api. Done!
