begin;

  create or replace function insert_target_host_set_subtype() returns trigger
  as $$
  declare
    host_catalog_id wt_public_id;
  begin
    select catalog_id into host_catalog_id
      from host_set
     where host_set.public_id = new.host_set_id;

    insert into target_host_source
      (target_id, project_id, catalog_id, host_id, host_set_id, host_type, type, create_time)
      select new.target_id, new.project_id, host_catalog_id, host_id, new.host_set_id, 'static', 'host_set', new.create_time
        from static_host_set_member
       where static_host_set_member.set_id = new.host_set_id;
    
    insert into target_host_source
      (target_id, project_id, catalog_id, host_id, host_set_id, host_type, type, create_time)
      select new.target_id, new.project_id, host_catalog_id, host_id, new.host_set_id, 'plugin', 'host_set', new.create_time
        from host_plugin_set_member
       where host_plugin_set_member.set_id = new.host_set_id;
    
    return new;
  end;
  $$ language plpgsql;

  -- create trigger insert_target_host_set_subtype after insert on target_host_set
  --   for each row execute function insert_target_host_set_subtype();

  create or replace function insert_target_host_subtype() returns trigger
  as $$
  declare
    host_catalog_id wt_public_id;
    host_type text;
  begin
    select catalog_id into host_catalog_id
      from host
     where host.public_id = new.host_id;

    select "static" into host_type
      from static_host_set_member
     where static_host_set_member.host_id = new.host_id;

    select "plugin" into host_type
      from host_plugin_set_member
     where host_plugin_set_member.host_id = new.host_id;
    
    insert into target_host_source
      (target_id, project_id, catalog_id, host_id, host_type, type, create_time)
    values
      (new.target_id, new.project_id, host_catalog_id, new.host_id, host_type, 'host', new.create_time);

    return new;
  end;
  $$ language plpgsql;

  -- target_host is a subtype of target_host_source
  create table target_host(
    target_id wt_public_id,
    host_id wt_public_id,
    create_time wt_timestamp,
    project_id wt_public_id not null,
    primary key(project_id, target_id, host_id),
    constraint target_fkey foreign key (project_id, target_id)
      references target (project_id, public_id)
      on delete cascade
      on update cascade,
    constraint host_fkey foreign key (project_id, host_id)
      references host (project_id, public_id)
      on delete cascade
      on update cascade
  );

  create trigger immutable_columns before update on target_host
    for each row execute procedure immutable_columns('target_id', 'project_id', 'host_id', 'create_time');

  create trigger insert_target_host before insert on target_host
    for each row execute function insert_project_id();

  -- create trigger insert_target_host_subtype after insert on target_host
  --   for each row execute function insert_target_host_subtype();

  -- Replaced by target_host_source
  drop view target_set;
  
  -- create table target_host_source(
  --   target_id wt_public_id,
  --   project_id wt_public_id,
  --   catalog_id wt_public_id,
  --   host_id wt_public_id,
  --   host_set_id wt_public_id,
  --   host_type text not null, -- create enum type
  --   type text not null, -- create enum type
  --   create_time wt_timestamp,
  --   primary key(project_id, target_id, catalog_id, host_id),
  --   constraint target_host_set_fkey foreign key (project_id, target_id, host_set_id)
  --     references target_host_set (project_id, target_id, host_set_id)
  --     on delete cascade
  --     on update cascade,
  --   constraint target_host_fkey foreign key (project_id, target_id, host_id)
  --     references target_host (project_id, target_id, host_id)
  --     on delete cascade
  --     on update cascade
  -- );
  -- comment on table target_host_source is
  -- 'target_host_source is a table where each row contains a host source that is associated to at least one target. The host source can either be a Host or Host Set.';

  -- create trigger immutable_columns before update on target_host_source
  --   for each row execute procedure immutable_columns('target_id', 'project_id', 'host_source_id', 'catalog_id', 'host_type', 'type', 'create_time');

  -- Replaces target_set view

  create view target_host_source as
    with
    target_static_host_set_member (target_id, host_id, host_set_id, catalog_id, project_id, type, host_type) as (
      select target_id, host_id, host_set_id, static_host_set_member.catalog_id, project_id, 'host_set' as type, 'static' as host_type
        from target_host_set
        join static_host_set_member on target_host_set.host_set_id = static_host_set_member.set_id
    ),
    target_plugin_host_set_member (target_id, host_id, host_set_id, catalog_id, project_id, type, host_type) as (
      select target_id, host_id, host_set_id, host_plugin_set_member.catalog_id, project_id, 'host_set' as type, 'plugin' as host_type
        from target_host_set
        join host_plugin_set_member on target_host_set.host_set_id = host_plugin_set_member.set_id
    ),
    target_static_host (target_id, host_id, catalog_id, project_id, type, host_type) as (
      select target_id, host_id, static_host.catalog_id, target_host.project_id, 'host' as type, 'static' as host_type
        from target_host
        join static_host on target_host.host_id = static_host.public_id
    ),
    target_plugin_host (target_id, host_id, catalog_id, project_id, type, host_type) as (
      select target_id, host_id, host_plugin_host.catalog_id, target_host.project_id, 'host' as type, 'plugin' as host_type
        from target_host
        join host_plugin_host on target_host.host_id = host_plugin_host.public_id
    )
    select target_id, host_id, null as host_set_id, catalog_id, project_id, type, host_type 
      from target_static_host
     union
    select target_id, host_id, null as host_set_id, catalog_id, project_id, type, host_type
      from target_plugin_host
     union
    select target_id, host_id, host_set_id, catalog_id, project_id, type, host_type
      from target_static_host_set_member
     union
    select target_id, host_id, host_set_id, catalog_id, project_id, type, host_type
      from target_plugin_host_set_member;
  comment on view target_host_source is
  'target_host_source is a view where each row contains a host source that is associated to at least one target. The host source can be directly associated to a target or indirectly using a Host Set.';

commit;