begin;

create table target_multi (
  public_id wt_public_id,
  project_id wt_public_id,
  primary key(public_id, project_id),
  constraint target_fkey foreign key (project_id, public_id)
      references target (project_id, public_id)
      on delete cascade
      on update cascade
);

create table target_single (
  public_id wt_public_id,
  address text not null,
  primary key(public_id),
  constraint target_fkey foreign key (public_id)
      references target (public_id)
      on delete cascade
      on update cascade
);

alter table target_host_set
  drop constraint target_fkey,
  add constraint target_multi_fkey foreign key (project_id, target_id)
      references target_multi (project_id, public_id)
      on delete cascade
      on update cascade
;

commit;