begin;

  -- target_host
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

  create view target_host_source as
    with
    target_static_host_set_member (target_id, host_id) as (
      select target_id, host_id, project_id
        from target_host_set
        join static_host_set_member on target_host_set.host_set_id = static_host_set_member.set_id
    ),
    target_plugin_host_set_member (target_id, host_id) as (
      select target_id, host_id, project_id
        from target_host_set
        join host_plugin_set_member on target_host_set.host_set_id = host_plugin_set_member.set_id
    )
    select target_id, host_id 
      from target_host
     union
    select target_id, host_id
      from target_static_host_set_member
     union
    select target_id, host_id 
      from target_plugin_host_set_member;
  comment on view target_host_source is
  'target_host_source is a view where each row contains a host source that is associated to at least one target. The host source can be directly associated to a target or indirectly using a Host Set.';

commit;