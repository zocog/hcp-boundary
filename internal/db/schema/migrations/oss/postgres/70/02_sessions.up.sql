begin;

  create table session_target_address (
    public_id wt_public_id,
    target_id wt_public_id,
    constraint target_fkey foreign key (target_id)
        references target_address (public_id)
        on delete cascade
        on update cascade,
    constraint session_fkey foreign key (public_id)
        references session (public_id)
        on delete cascade
        on update cascade,
    constraint session_id_target_address_uq
        unique(public_id, target_id)
  );
  comment on table session_target_address is
    'session_target_address entries represent a session that is using a network address that is assigned directly to a Target.';

  create trigger immutable_columns before update on session_target_address
    for each row execute procedure immutable_columns('public_id');

  create trigger cancel_session_with_null_fk before update of target_id on session_target_address
    for each row execute procedure cancel_session_with_null_fk();

  create table session_host_set (
    public_id wt_public_id,
    host_set_id wt_public_id,
    constraint host_set_fkey foreign key (host_set_id)
        references host_set (public_id)
        on delete cascade
        on update cascade,
    constraint session_fkey foreign key (public_id)
        references session (public_id)
        on delete cascade
        on update cascade,
    constraint session_id_host_set_id_uq
        unique(public_id, host_set_id)
  );
  comment on table session_host_set is
    'session_host_set entries represent a session that is using a Host Set.';

  create trigger immutable_columns before update on session_host_set
    for each row execute procedure immutable_columns('public_id');

  create trigger cancel_session_with_null_fk before update of host_set_id on session_host_set
    for each row execute procedure cancel_session_with_null_fk();

  create or replace function set_session_host_set_to_null() returns trigger
  as $$
  begin
    update session set
      host_set_id = null
    where session.public_id = new.public_id;
    return new;
  end;
  $$ language plpgsql;
  comment on function set_session_host_set_to_null() is
    'set_session_host_set_to_null updates the host_set_id column in the session table to null.';

  create trigger set_session_host_set_to_null after delete on session_host_set
    for each row execute procedure set_session_host_set_to_null();

  create table session_host (
    public_id wt_public_id,
    host_id wt_public_id,
    constraint host_fkey foreign key (host_id)
        references host (public_id)
        on delete cascade
        on update cascade,
    constraint session_fkey foreign key (public_id)
        references session (public_id)
        on delete cascade
        on update cascade,
    constraint session_id_host_id_uq
        unique(public_id, host_id)
  );
  comment on table session_host is
    'session_host entries represent a session that is using a Host.';

  create trigger immutable_columns before update on session_host
    for each row execute procedure immutable_columns('public_id');

  create trigger cancel_session_with_null_fk before update of host_id on session_host
    for each row execute procedure cancel_session_with_null_fk();

  create or replace function set_session_host_to_null() returns trigger
  as $$
  begin
    update session set
      host_id = null
    where session.public_id = new.public_id;
    return new;
  end;
  $$ language plpgsql;
  comment on function set_session_host_to_null() is
    'set_session_host_to_null updates the host_id column in the session table to null.';

  create trigger set_session_host_to_null after delete on session_host
    for each row execute procedure set_session_host_to_null();

  create or replace function insert_session_associations() returns trigger
  as $$
  declare
  has_target_address bigint;
  begin

    if new.host_id is not null then
      insert into session_host
        (public_id, host_id)
      values
        (new.public_id, new.host_id);
    end if;

    if new.host_set_id is not null then
      insert into session_host_set
        (public_id, host_set_id)
      values
        (new.public_id, new.host_set_id);
    end if;

    select count(*)
      into has_target_address
    from target_address as t
    where t.public_id = new.target_id;

    if has_target_address > 0 then
      insert into session_target_address
        (public_id, target_id)
      values
        (new.public_id, new.target_id);
    end if;

    return new;
  end;
  $$ language plpgsql;
  comment on function insert_session_associations() is
    'insert_session_associations inserts entries into one or more of the following tables: session_host, session_host_set, session_target_address.'
    'Inserting into the tables depends on the session using a host source or a direct network address association.';

  create trigger insert_session_associations after insert on session
    for each row execute procedure insert_session_associations();

  alter table session
    drop constraint session_host_id_fkey,
    drop constraint session_host_set_id_fkey
  ;

  drop trigger cancel_session_with_null_fk on session;
  create trigger cancel_session_with_null_fk before update of user_id, target_id, auth_token_id, project_id on session
    for each row execute procedure cancel_session_with_null_fk();

commit;
