-- Production credit / generation / storage controls
-- Safe to re-run. Does NOT delete media.

-- Generation lifecycle + audit columns
alter table generations add column if not exists idempotency_key text;
alter table generations add column if not exists pricing_version int not null default 1;
alter table generations add column if not exists provider text;
alter table generations add column if not exists model text;
alter table generations add column if not exists provider_request_id text;
alter table generations add column if not exists is_saved boolean not null default false;
alter table generations add column if not exists input_expires_at timestamptz;
alter table generations add column if not exists output_expires_at timestamptz;
alter table generations add column if not exists deleted_at timestamptz;
alter table generations add column if not exists started_at timestamptz;
alter table generations add column if not exists completed_at timestamptz;
alter table generations add column if not exists width int;
alter table generations add column if not exists height int;

-- One client retry key per user (nullable allowed for legacy rows)
create unique index if not exists generations_user_idempotency_uidx
  on generations (user_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists generations_status_created_idx
  on generations (status, created_at desc);

create index if not exists generations_input_expires_idx
  on generations (input_expires_at)
  where deleted_at is null and input_expires_at is not null;

create index if not exists generations_output_expires_idx
  on generations (output_expires_at)
  where deleted_at is null and output_expires_at is not null;

create index if not exists generations_user_status_idx
  on generations (user_id, status)
  where deleted_at is null;

-- Soft-delete friendly listing
create index if not exists generations_user_active_created_idx
  on generations (user_id, created_at desc)
  where deleted_at is null;

-- Expand ledger types without breaking existing rows
do $$
begin
  alter table credit_transactions drop constraint if exists credit_transactions_type_check;
exception
  when undefined_object then null;
end $$;

alter table credit_transactions
  drop constraint if exists credit_transactions_type_check;

alter table credit_transactions
  add constraint credit_transactions_type_check
  check (type in (
    'grant',
    'spend',
    'refund',
    'adjustment',
    'purchase',
    'generation_debit',
    'generation_refund',
    'manual_adjustment',
    'admin_adjustment',
    'expiration',
    'reversal'
  ));

-- Keep legacy spend/refund values working; new code may write generation_debit/refund aliases via reason.

notify pgrst, 'reload schema';
