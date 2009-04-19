-- drop database ykksm;
create database ykksm;
use ykksm;

create table yubikeys (
  id int not null auto_increment,

  -- identities:
  serialNr int not null,
  publicName varchar(16) unique not null,

  -- timestamps:
  created datetime not null,

  -- the data:
  internalName varchar(12) not null,
  aesKey varchar(32) not null,
  lockCode varchar(12) not null,

  -- key creator, typically pgp key id of key generator
  creator varchar(8) not null,

  -- various flags:
  active boolean default true,
  hardware boolean default true,

  primary key (id)
  -- MySQL generates an index automatically for columns marked 'unique'
  -- if this doesn't seem to happen, add: 'key (publicName)'
  -- use, e.g., explain select * from yubikeys where publicName = 'foo';
  -- and make sure it uses a key to find the column.
);

-- drop user ykksmreader;
create user ykksmreader;
grant select on ykksm.yubikeys to 'ykksmreader'@'localhost';
flush privileges;
