alter table public.animal enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'animal'
      and policyname = 'admin_update_animal'
  ) then
    create policy "admin_update_animal"
      on public.animal
      for update
      using (
        exists (
          select 1
          from public."user" u
          where u.id = auth.uid()
            and lower(u.role) = 'admin'
        )
      )
      with check (
        exists (
          select 1
          from public."user" u
          where u.id = auth.uid()
            and lower(u.role) = 'admin'
        )
      );
  end if;
end $$;
