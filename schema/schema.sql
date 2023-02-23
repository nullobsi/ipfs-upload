create table users (
    uid integer not null primary key,
    username text unique not null
);

create table access_token (
    uid integer NOT NULL,
    token text unique NOT NULL,
    app_name text NOT NULL,
    id integer NOT NULL primary key,
    foreign key (uid) references users(uid)
);

create table pins (
    id text not null primary key default (lower(hex( randomblob(4)) || '-' || hex( randomblob(2))
        || '-' || '4' || substr( hex( randomblob(2)), 2) || '-'
        || substr('AB89', 1 + (abs(random()) % 4) , 1)  ||
        substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)))),
    created_at text default (strftime('%Y-%m-%dT%H:%M:%SZ')) not null,
    cid text not null,
    name text not null,
    uid integer not null,
    app_name text not null,
    foreign key (uid) references users(uid)
);

create unique index pins_cid_uid_uindex on pins (cid, uid);
