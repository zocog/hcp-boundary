begin;

  -- Replaces trigger from 44/04_sessions.up.sql
  drop trigger cancel_session_with_null_fk on session;
  create or replace function cancel_session_with_null_fk() returns trigger
  as $$
  begin
    case 
      when new.auth_token_id is null then
        perform cancel_session(new.public_id);  
      when new.project_id is null then
        perform cancel_session(new.public_id);
      when new.target_id is null then
        perform cancel_session(new.public_id);
      when new.user_id is null then
        perform cancel_session(new.public_id);
    end case;
    return new;
  end;
  $$ language plpgsql;
  
  create trigger cancel_session_with_null_fk before update of auth_token_id, project_id, target_id, user_id on session
    for each row execute procedure cancel_session_with_null_fk();

  create table session_target_address (
    public_id wt_public_id,
    target_id wt_public_id,
    constraint target_address_fkey foreign key (target_id)
        references target_address (public_id)
        on delete set null
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

  create or replace function cancel_session_with_null_target_address_fk() returns trigger
  as $$
  begin
    if new.target_id is null then
      perform cancel_session(new.public_id);
      delete from session_target_address where public_id = new.public_id;
    end if;
    return new;
  end;
  $$ language plpgsql;
  
  create trigger cancel_session_with_null_target_address_fk after update of target_id on session_target_address
    for each row execute procedure cancel_session_with_null_target_address_fk();

  create table session_host_set (
    public_id wt_public_id,
    host_set_id wt_public_id,
    constraint host_set_fkey foreign key (host_set_id)
        references host_set (public_id)
        on delete set null
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

  create or replace function cancel_session_with_null_host_set_fk() returns trigger
  as $$
  begin
    if new.host_set_id is null then
      perform cancel_session(new.public_id);
      delete from session_host_set where public_id = new.public_id;
    end if;
    return new;
  end;
  $$ language plpgsql;
  
  create trigger cancel_session_with_null_host_set_fk after update of host_set_id on session_host_set
    for each row execute procedure cancel_session_with_null_host_set_fk();

  create table session_host (
    public_id wt_public_id,
    host_id wt_public_id,
    constraint host_fkey foreign key (host_id)
        references host (public_id)
        on delete set null
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

  create or replace function cancel_session_with_null_host_fk() returns trigger
  as $$
  begin
    if new.host_id is null then
      perform cancel_session(new.public_id);
      delete from session_host where public_id = new.public_id;
    end if;
    return new;
  end;
  $$ language plpgsql;

  create trigger cancel_session_with_null_host_fk after update of host_id on session_host
    for each row execute procedure cancel_session_with_null_host_fk();

  drop view session_list;
  alter table session
    drop constraint session_host_id_fkey,
    drop constraint session_host_set_id_fkey,
    drop column host_id,
    drop column host_set_id
  ;

  -- Replaces trigger from 44/04_sessions.up.sql
  drop trigger insert_session on session;
  create or replace function insert_session() returns trigger
  as $$
  begin
    case
      when new.user_id is null then
        raise exception 'user_id is null';
      when new.target_id is null then
        raise exception 'target_id is null';
      when new.auth_token_id is null then
        raise exception 'auth_token_id is null';
      when new.project_id is null then
        raise exception 'project_id is null';
      when new.endpoint is null then
        raise exception 'endpoint is null';
    else
    end case;
    return new;
  end;
  $$ language plpgsql;

  create trigger insert_session before insert on session
    for each row execute procedure insert_session();

  -- Replaces view from 44/04_sessions.up.sql
  create view session_list as
  select
    s.public_id, s.user_id, s.target_id,
    coalesce(sh.host_id, 'Not Applicable') as host_id, coalesce(shs.host_set_id, 'Not Applicable') as host_set_id,
    s.auth_token_id, s.project_id, s.certificate, s.expiration_time,
    s.connection_limit, s.tofu_token, s.key_id, s.termination_reason, s.version,
    s.create_time, s.update_time, s.endpoint, s.worker_filter,
    ss.state, ss.previous_end_time, ss.start_time, ss.end_time, sc.public_id as connection_id,
    sc.client_tcp_address, sc.client_tcp_port, sc.endpoint_tcp_address, sc.endpoint_tcp_port,
    sc.bytes_up, sc.bytes_down, sc.closed_reason
  from session s
  join session_state ss on s.public_id = ss.session_id
  left join session_connection sc on s.public_id = sc.session_id
  left join session_host sh on s.public_id = sh.public_id
  left join session_host_set shs on s.public_id = shs.public_id;

commit;
