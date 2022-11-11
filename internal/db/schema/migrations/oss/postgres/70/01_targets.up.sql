begin;

  create table target_address (
    public_id wt_public_id,
    address text not null,
    primary key(public_id),
    constraint target_fkey foreign key (public_id)
        references target (public_id)
        on delete cascade
  );

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

commit;