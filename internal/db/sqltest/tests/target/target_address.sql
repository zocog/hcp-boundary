begin;
  select plan(5);
  select wtt_load('widgets', 'iam', 'kms', 'auth', 'hosts');

  insert into target
    (project_id,     public_id)
  values
    ('p____bwidget', 'test____addr');

  prepare insert_valid_target_address as
    insert into target_address
      (public_id,       address)
    values
      ('test____addr', '0.0.0.0');
  select lives_ok('insert_valid_target_address', 'insert valid target_address failed');

  prepare insert_valid_target_host_set as
    insert into target_host_set
      (project_id,     target_id,      host_set_id)
    values
      ('p____bwidget', 'test____addr', 's___1wb-plghs');
  select lives_ok('insert_valid_target_host_set', 'insert valid target_host_set failed');

  -- validate target_address rows are removed
  select is(count(*), 0::bigint)
    from target_address
   where public_id = 'test____addr';

  select lives_ok('insert_valid_target_address', 'insert valid target_address failed');

  -- validate target_host_set rows are removed
  select is(count(*), 0::bigint)
    from target_host_set
   where target_id = 'test____addr';

  select * from finish();
rollback;
