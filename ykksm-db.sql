create table yubikeys (
  -- identities:
  serialNr int not null,
  publicName varchar(16) unique not null,

  -- timestamps:
  created varchar(24) not null,

  -- the data:
  internalName varchar(12) not null,
  aesKey varchar(32) not null,
  lockCode varchar(12) not null,

  -- key creator, typically pgp key id of key generator
  creator varchar(8) not null,

  -- various flags:
  active boolean default true,
  hardware boolean default true,

  primary key (publicName)
);
