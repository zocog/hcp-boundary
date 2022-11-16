begin;

  -- replaced function in 26/03_wh_network_address_dimensions.up.sql
  create or replace function wh_upsert_host() returns trigger
  as $$
  declare
    p_host_set_id  wt_public_id;
    p_target_id    wt_public_id;
    p_host_key     wh_dim_key;
    src            whx_host_dimension_target%rowtype;
    target         whx_host_dimension_target%rowtype;
    addr_group_key wh_dim_key;
  begin
    select target_id into p_target_id
      from session
    where session.public_id = new.public_id;

    select host_set_id into p_host_set_id
      from session_host_set
    where session_host_set.public_id = new.public_id;

    if p_target_id is null then
      raise exception 'target_id is null';
    end if;

    if p_host_set_id is null then
      raise exception 'host_set_id is null';
    end if;

    select * into target
    from whx_host_dimension_target as t
    where t.host_id               = new.host_id
      and t.host_set_id           = p_host_set_id
      and t.target_id             = p_target_id;

    select wh_upsert_network_address_dimension(new.host_id) into addr_group_key;

    select target.key, addr_group_key, t.* into src
    from whx_host_dimension_source as t
    where t.host_id               = new.host_id
      and t.host_set_id           = p_host_set_id
      and t.target_id             = p_target_id;

    if src is distinct from target then

      -- expire the current row
      update wh_host_dimension
      set current_row_indicator = 'Expired',
          row_expiration_time   = current_timestamp
      where host_id               = new.host_id
        and host_set_id           = p_host_set_id
        and target_id             = p_target_id
        and current_row_indicator = 'Current';

      -- insert a new row
      insert into wh_host_dimension (
        host_id,                    host_type,                  host_name,                       host_description,
        network_address_group_key,
        host_set_id,                host_set_type,              host_set_name,                   host_set_description,
        host_catalog_id,            host_catalog_type,          host_catalog_name,               host_catalog_description,
        target_id,                  target_type,                target_name,                     target_description,
        target_default_port_number, target_session_max_seconds, target_session_connection_limit,
        project_id,                 project_name,               project_description,
        organization_id,            organization_name,          organization_description,
        current_row_indicator,      row_effective_time,         row_expiration_time
      )
      select host_id,                    host_type,                  host_name,                       host_description,
             addr_group_key,
             host_set_id,                host_set_type,              host_set_name,                   host_set_description,
             host_catalog_id,            host_catalog_type,          host_catalog_name,               host_catalog_description,
             target_id,                  target_type,                target_name,                     target_description,
             target_default_port_number, target_session_max_seconds, target_session_connection_limit,
             project_id,                 project_name,               project_description,
             organization_id,            organization_name,          organization_description,
             'Current',                  current_timestamp,          'infinity'::timestamptz
      from whx_host_dimension_source
      where host_id               = new.host_id
        and host_set_id           = p_host_set_id
        and target_id             = p_target_id;

    end if;

    select key into p_host_key
    from wh_host_dimension as t
    where t.current_row_indicator = 'Current'
      and t.host_id               = new.host_id
      and t.host_set_id           = p_host_set_id
      and t.target_id             = p_target_id;

    update wh_session_accumulating_fact
      set host_key = p_host_key
    where session_id = new.public_id;

    return new;
  end;
  $$ language plpgsql;

  create trigger wh_update_session_connection_accumulating_fact after insert on session_host
    for each row execute procedure wh_upsert_host();

  -- replaced function in 16/04_wh_credential_dimension.up.sql
  create or replace function wh_insert_session() returns trigger
  as $$
  declare
    new_row wh_session_accumulating_fact%rowtype;
  begin
    with
    pending_timestamp (date_dim_key, time_dim_key, ts) as (
      select wh_date_key(start_time), wh_time_key(start_time), start_time
        from session_state
       where session_id = new.public_id
         and state      = 'pending'
    )
    insert into wh_session_accumulating_fact (
           session_id,
           auth_token_id,
           host_key,
           user_key,
           credential_group_key,
           session_pending_date_key,
           session_pending_time_key,
           session_pending_time
    )
    select new.public_id,
           new.auth_token_id,
           'no host source', -- will be updated by wh_upsert_host
           wh_upsert_user(new.user_id, new.auth_token_id),
           'no credentials', -- will be updated by wh_upsert_credentail_group
           pending_timestamp.date_dim_key,
           pending_timestamp.time_dim_key,
           pending_timestamp.ts
      from pending_timestamp
      returning * into strict new_row;
    return null;
  end;
  $$ language plpgsql;

  insert into wh_host_dimension (
    key,
    host_id, host_type, host_name, host_description,
    host_set_id, host_set_type, host_set_name, host_set_description,
    host_catalog_id, host_catalog_type, host_catalog_name, host_catalog_description, 
    target_id, target_type, target_name, target_description, target_default_port_number, target_session_max_seconds, target_session_connection_limit,
    project_id, project_name, project_description, organization_id, organization_name, organization_description,
    current_row_indicator, row_effective_time, row_expiration_time, network_address_group_key
  )
  values
  (
    'no host source',
    'None',                'None',                  'None',                      'None',
    'None',                'None',                  'None',                      'None',
    'None',                'None',                  'None',                      'None',
    'None',                'None',                  'None',                      'None',                   -1,                  -1,               -1,
    '00000000000',         'None',                  'None',                      '00000000000',        'None',              'None',
    'Current',              now(),                  'infinity'::timestamptz,     'Unknown'
  );

  -- The whx_host_direct_network_dimension_source view shows the current values in the
  -- operational tables of the host dimension for targets with direct associations.
  create view whx_host_direct_network_dimension_source as
  with
  targets (project_id, public_id, name, description, default_port, session_max_seconds, session_connection_limit) as (
    select t.project_id, t.public_id, t.name, t.description, t.default_port, t.session_max_seconds, t.session_connection_limit
      from target_tcp as t
      right join target_address as ta on t.public_id = ta.public_id
  ),
  target_source (host_id, host_type, host_name, host_description,
    host_set_id, host_set_type, host_set_name, host_set_description,
    host_catalog_id, host_catalog_type, host_catalog_name, host_catalog_description,
    target_id, target_type, target_name, target_description, target_default_port_number, target_session_max_seconds, target_session_connection_limit,
    project_id, project_name, project_description, host_organization_id, host_organization_name, host_organization_description) as (
      select
         'Not Applicable'                as host_id,
         'Not Applicable'                as host_type,
         'Not Applicable'                as host_name,
         'Not Applicable'                as host_description,
         'Not Applicable'                as host_set_id,
         'Not Applicable'                as host_set_type,
         'Not Applicable'                as host_set_name,
         'Not Applicable'                as host_set_description,
         'Not Applicable'                as host_catalog_id,
         'Not Applicable'                as host_catalog_type,
         'Not Applicable'                as host_catalog_name,
         'Not Applicable'                as host_catalog_description,
         t.public_id                     as target_id,
         'tcp target'                    as target_type,
         coalesce(t.name, 'None')        as target_name,
         coalesce(t.description, 'None') as target_description,
         coalesce(t.default_port, 0)     as target_default_port_number,
         t.session_max_seconds           as target_session_max_seconds,
         t.session_connection_limit      as target_session_connection_limit,
         p.public_id                     as project_id,
         coalesce(p.name, 'None')        as project_name,
         coalesce(p.description, 'None') as project_description,
         o.public_id                     as host_organization_id,
         coalesce(o.name, 'None')        as host_organization_name,
         coalesce(o.description, 'None') as host_organization_description
    from targets as t,
         iam_scope as p,
         iam_scope as o
   where p.public_id = t.project_id
     and p.type = 'project'
     and o.public_id = p.parent_id
     and o.type = 'org'
  )
  select * from target_source;

  -- keep this simple for now, not sure what the other values should be?
  -- currently with whx_network_address_dimension_source, it can either come from
  -- tables: host_dns_name, host_ip_address, static_host
  create function wh_upsert_direct_network_address_dimension(p_address text) returns wh_dim_key
  as $$
  declare
    nag_key wh_dim_key;
  begin
    insert into wh_network_address_dimension 
      (address, address_type, ip_address_family, private_ip_address_indicator, dns_name, ip4_address, ip6_address)
    values
      (p_address, 'Not Applicable', 'Not Applicable', 'Not Applicable', 'Not Applicable', 'Not Applicable', 'Not Applicable') on conflict do nothing;

    select distinct network_address_group_key into nag_key
    from wh_network_address_group_membership g
    where g.network_address = p_address;

    if nag_key is null then
      insert into wh_network_address_group default values returning key into nag_key;
      insert into wh_network_address_group_membership
        (network_address_group_key, network_address)
      values
        (nag_key, p_address);
    end if;

    return nag_key;
  end
  $$ language plpgsql;

  create or replace function wh_upsert_host_direct_network_address() returns trigger
  as $$
  declare
    p_address      text;
    src            whx_host_dimension_target%rowtype;
    target         whx_host_dimension_target%rowtype;
    addr_group_key wh_dim_key;
    p_host_key     wh_dim_key;
  begin
    select address into p_address
      from target_address
    where target_address.public_id = new.target_id;

    if p_address is null then
      raise exception 'target address is null';
    end if;

    select * into target
    from whx_host_dimension_target as t
    where t.host_id               = 'Not Applicable'
      and t.host_set_id           = 'Not Applicable'
      and t.target_id             = new.target_id;

    select wh_upsert_direct_network_address_dimension(p_address) into addr_group_key;

    select target.key, addr_group_key, t.* into src
    from whx_host_direct_network_dimension_source as t
    where t.host_id               = 'Not Applicable'
      and t.host_set_id           = 'Not Applicable'
      and t.target_id             = new.target_id;

    if src is distinct from target then

      -- expire the current row
      update wh_host_dimension
      set current_row_indicator = 'Expired',
          row_expiration_time   = current_timestamp
      where host_id               = 'Not Applicable'
        and host_set_id           = 'Not Applicable'
        and target_id             = new.target_id
        and current_row_indicator = 'Current';

      -- insert a new row
      insert into wh_host_dimension (
        host_id,                    host_type,                  host_name,                       host_description,
        network_address_group_key,
        host_set_id,                host_set_type,              host_set_name,                   host_set_description,
        host_catalog_id,            host_catalog_type,          host_catalog_name,               host_catalog_description,
        target_id,                  target_type,                target_name,                     target_description,
        target_default_port_number, target_session_max_seconds, target_session_connection_limit,
        project_id,                 project_name,               project_description,
        organization_id,            organization_name,          organization_description,
        current_row_indicator,      row_effective_time,         row_expiration_time
      )
      select host_id,                    host_type,                  host_name,                       host_description,
             addr_group_key,
             host_set_id,                host_set_type,              host_set_name,                   host_set_description,
             host_catalog_id,            host_catalog_type,          host_catalog_name,               host_catalog_description,
             target_id,                  target_type,                target_name,                     target_description,
             target_default_port_number, target_session_max_seconds, target_session_connection_limit,
             project_id,                 project_name,               project_description,
             host_organization_id,       host_organization_name,     host_organization_description,
             'Current',                  current_timestamp,          'infinity'::timestamptz
      from whx_host_direct_network_dimension_source
      where target_id = new.target_id;

    end if;

    select key into p_host_key
    from wh_host_dimension as t
    where t.current_row_indicator = 'Current'
      and t.host_id               = 'Not Applicable'
      and t.host_set_id           = 'Not Applicable'
      and t.target_id             = new.target_id;

    update wh_session_accumulating_fact
      set host_key = p_host_key
    where session_id = new.public_id;

    return new;
  end;
  $$ language plpgsql;

  create trigger wh_update_session_connection_accumulating_fact after insert on session_target_address
    for each row execute procedure wh_upsert_host_direct_network_address();

commit;
