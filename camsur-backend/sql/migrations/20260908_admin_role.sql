-- Admin role for the internal admin panel. Safe to re-run.

alter table users
  add column if not exists role text not null default 'user'
  check (role in ('user', 'admin'));

notify pgrst, 'reload schema';
