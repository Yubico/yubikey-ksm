create table yubikeys (
  -- identities:
  serialnr int not null,
  publicname varchar(16) unique not null,

  -- timestamps:
  created varchar(24) not null,

  -- the data:
  internalname varchar(12) not null,
  aeskey varchar(32) not null,
  lockcode varchar(12) not null,

  -- key creator, typically pgp key id of key generator
  creator varchar(8) not null,

  -- various flags:
  active boolean default true,
  hardware boolean default true,

  primary key (publicname)
);
