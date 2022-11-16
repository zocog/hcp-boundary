begin;

  create table target_address (
    public_id wt_public_id primary key,
    address text not null
      constraint address_must_be_more_than_2_characters
      check(length(trim(address)) > 2)
      constraint address_must_be_less_than_256_characters
      check(length(trim(address)) < 256),
    constraint target_fkey foreign key (public_id)
        references target (public_id)
        on delete cascade
        on update cascade
  );
  comment on table target_address is
    'target_address entries represent a network address assigned to a target.';

  create trigger immutable_columns before update on target_address
    for each row execute function immutable_columns('public_id');

  create or replace function remove_target_address() returns trigger
  as $$
  begin
    delete from target_address
      where public_id = new.target_id;
    return new;
  end;
  $$ language plpgsql;
  comment on function remove_target_address() is
    'remove_target_address will remove any existing rows in the target_address table because target to host source is a mutually exclusive relationship to a network address.';

  create trigger remove_target_address after insert on target_host_set
    for each row execute function remove_target_address();

  create or replace function remove_target_host_set() returns trigger
  as $$
  begin
    delete from target_host_set
      where target_id = new.public_id;
    return new;
  end;
  $$ language plpgsql;
  comment on function remove_target_host_set() is
    'remove_target_host_set will remove any existing rows in the target_host_set table because target to host source is a mutually exclusive relationship to a network address.';

  create trigger remove_target_host_set after insert on target_address
    for each row execute function remove_target_host_set();

commit;