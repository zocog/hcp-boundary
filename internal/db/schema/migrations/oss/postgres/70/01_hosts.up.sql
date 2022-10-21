begin;

  -- host
  alter table host
    add column project_id wt_public_id,
    add constraint host_project_id_public_id_uq
      unique(project_id, public_id)
  ;

  update host
     set (project_id) =
         (select project_id
            from host_catalog
           where host_catalog.public_id = host.catalog_id
         )
  ;

  alter table host
    alter column project_id set not null,
    drop constraint host_catalog_fkey,
    add constraint host_catalog_fkey
      foreign key (project_id, catalog_id)
        references host_catalog (project_id, public_id)
        on delete cascade
        on update cascade,
    -- Replaces host_catalog_id_public_id_key
    add constraint host_project_id_catalog_id_public_id_uq
      unique(project_id, catalog_id, public_id)
  ;

  drop trigger immutable_columns on host;
  create trigger immutable_columns before update on host
    for each row execute function immutable_columns('public_id', 'catalog_id', 'project_id');

  -- insert_host_subtype() is a before insert trigger
  -- function for subtypes of host
  -- Replaces the insert_host_subtype function defined in 0/20_host.up.sql
  create or replace function insert_host_subtype() returns trigger
  as $$
  begin

    select project_id into new.project_id
      from host_catalog
     where host_catalog.public_id = new.catalog_id;

    insert into host
      (public_id, catalog_id, project_id)
    values
      (new.public_id, new.catalog_id, new.project_id);
    return new;
  end;
  $$ language plpgsql;

-- static_host_set
  alter table static_host
    add column project_id wt_public_id
  ;

  update static_host
     set (project_id) =
         (select project_id
            from host
           where host.public_id = static_host.public_id
         )
  ;

  alter table static_host
    alter column project_id set not null,
    add constraint host_fkey
      foreign key (project_id, catalog_id, public_id)
        references host (project_id, catalog_id, public_id)
        on delete cascade
        on update cascade,
    drop constraint if exists static_host_catalog_id_fkey1, -- pg 11
    drop constraint if exists static_host_catalog_id_public_id_fkey -- pg 12, 13, 14
  ;

  drop trigger immutable_columns on static_host;
  create trigger immutable_columns before update on static_host
    for each row execute procedure immutable_columns('public_id', 'catalog_id', 'project_id', 'create_time');

-- host_plugin_set
  alter table host_plugin_host
    add column project_id wt_public_id
  ;

  update host_plugin_host
     set (project_id) =
         (select project_id
            from host
           where host.public_id = host_plugin_host.public_id
         )
  ;

  alter table host_plugin_host
    alter column project_id set not null,
    drop constraint host_fkey,
    add constraint host_fkey
      foreign key (project_id, catalog_id, public_id)
        references host (project_id, catalog_id, public_id)
        on delete cascade
        on update cascade
  ;

  drop trigger immutable_columns on host_plugin_host;
  create trigger immutable_columns before update on host_plugin_host
    for each row execute procedure immutable_columns('public_id', 'catalog_id', 'project_id', 'create_time');

  alter table host
    drop constraint host_catalog_id_public_id_key
  ;

commit;