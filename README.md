# IPFS Upload
Simple IPFS remote pinning service and
HTTP upload provider.

In addition to providing a remote pinning endpoint
at /api, you can also POST uploads directly to the
root `/` with an access token and recieve a URL back:
```shell
$ curl -H "Authorization: Bearer ..." -F file=@file https://u.unix.dog/
https://unix.dog/ipfs/Qm...
```

## Setup
To setup this service locally, you will need:
- PostgreSQL (optional)
- LDAP service with password auth (optional)
- IPFS node with RPC API (Kubo)

Copy the config ipfs_upload.default.yml to
ipfs_upload.yml, and edit the config appropriately.
Then use hypnotoad or morbo to run `script/IpfsUpload`.
Log in, generate tokens, and point your IPFS remote pinning
to /api. Done!

## Databases
IPFS Upload supports PostgreSQL or SQLite. LDAP and in-database
password hashing with Argon2ID are also supported. Check the default
config to learn how to configure it properly.

When using in-database authentication, you can change your password
on the Access Token page. In the config, you can whitelist usernames.
The password will be set on first login.
