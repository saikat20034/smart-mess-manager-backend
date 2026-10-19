-- ==============================================================================
-- SMART MESS MANAGER - DATABASE SCHEMA & ROW LEVEL SECURITY (RLS) POLICIES
-- Target: Supabase (PostgreSQL 15+)
-- Currency: Bangladeshi Taka (BDT ৳)
-- ==============================================================================

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";

-- 2. PROFILES TABLE (Linked with Supabase Auth users)
create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    full_name text not null,
    phone text,
    bkash_number text,
    avatar_url text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Trigger to auto-create profile on auth signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
    insert into public.profiles (id, full_name, phone, avatar_url)
    values (
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', 'Mess Member'),
        new.raw_user_meta_data->>'phone',
        new.raw_user_meta_data->>'avatar_url'
    );
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- 3. MESSES TABLE
create table if not exists public.messes (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    address text,
    currency text not null default 'BDT',
    invite_code text unique not null,
    month_start_day int not null default 1 check (month_start_day between 1 and 28),
    breakfast_unit numeric(3,2) not null default 0.50,
    lunch_unit numeric(3,2) not null default 1.00,
    dinner_unit numeric(3,2) not null default 1.00,
    shared_expense_policy text not null default 'equal' check (shared_expense_policy in ('equal', 'per_meal')),
    created_by uuid references public.profiles(id) on delete set null,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- 4. MESS MEMBERS TABLE
create table if not exists public.mess_members (
    id uuid primary key default gen_random_uuid(),
    mess_id uuid not null references public.messes(id) on delete cascade,
    user_id uuid references public.profiles(id) on delete set null,
    name text not null,
    phone text,
    email text,
    room_number text,
    role text not null default 'member' check (role in ('manager', 'member')),
    status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
    joined_at date not null default current_date,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(mess_id, user_id)
);

-- Index for membership lookups
create index if not exists idx_mess_members_mess_id on public.mess_members(mess_id);
create index if not exists idx_mess_members_user_id on public.mess_members(user_id);

-- 5. MEAL ENTRIES TABLE
create table if not exists public.meal_entries (
    id uuid primary key default gen_random_uuid(),
    mess_id uuid not null references public.messes(id) on delete cascade,
    member_id uuid not null references public.mess_members(id) on delete cascade,
    date date not null,
    breakfast numeric(3,2) not null default 0.00 check (breakfast >= 0),
    lunch numeric(3,2) not null default 0.00 check (lunch >= 0),
    dinner numeric(3,2) not null default 0.00 check (dinner >= 0),
    total_units numeric(4,2) not null default 0.00 check (total_units >= 0),
    notes text,
    recorded_by uuid references public.profiles(id) on delete set null,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(mess_id, member_id, date)
);

create index if not exists idx_meal_entries_date on public.meal_entries(mess_id, date);
create index if not exists idx_meal_entries_member on public.meal_entries(member_id, date);

-- 6. EXPENSE CATEGORIES TABLE
create table if not exists public.expense_categories (
    id uuid primary key default gen_random_uuid(),
    mess_id uuid not null references public.messes(id) on delete cascade,
    name text not null,
    is_meal_related boolean not null default false,
    icon text default 'shopping-bag',
    created_at timestamptz default now()
);

-- 7. EXPENSES TABLE (Bazar & Shared Overhead)
create table if not exists public.expenses (
    id uuid primary key default gen_random_uuid(),
    mess_id uuid not null references public.messes(id) on delete cascade,
    category_id uuid references public.expense_categories(id) on delete set null,
    title text not null,
    amount numeric(12,2) not null check (amount > 0),
    date date not null default current_date,
    paid_by_member_id uuid references public.mess_members(id) on delete set null,
    is_meal_related boolean not null default true,
    receipt_url text,
    notes text,
    recorded_by uuid references public.profiles(id) on delete set null,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_expenses_date on public.expenses(mess_id, date);
create index if not exists idx_expenses_category on public.expenses(category_id);

-- 8. DEPOSITS TABLE (Member Payments)
create table if not exists public.deposits (
    id uuid primary key default gen_random_uuid(),
    mess_id uuid not null references public.messes(id) on delete cascade,
    member_id uuid not null references public.mess_members(id) on delete cascade,
    amount numeric(12,2) not null check (amount > 0),
    date date not null default current_date,
    payment_method text not null check (payment_method in ('bKash', 'Nagad', 'Rocket', 'Cash', 'Bank', 'Other')),
    transaction_ref text,
    notes text,
    recorded_by uuid references public.profiles(id) on delete set null,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_deposits_member on public.deposits(member_id);
create index if not exists idx_deposits_date on public.deposits(mess_id, date);

-- 9. MONTHLY SETTLEMENTS TABLE
create table if not exists public.monthly_settlements (
    id uuid primary key default gen_random_uuid(),
    mess_id uuid not null references public.messes(id) on delete cascade,
    month int not null check (month between 1 and 12),
    year int not null check (year >= 2020),
    total_meal_units numeric(10,2) not null default 0.00,
    total_meal_expenses numeric(12,2) not null default 0.00,
    total_shared_expenses numeric(12,2) not null default 0.00,
    meal_rate numeric(8,4) not null default 0.0000,
    is_finalized boolean not null default false,
    finalized_by uuid references public.profiles(id) on delete set null,
    finalized_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(mess_id, month, year)
);

-- 10. SETTLEMENT ITEMS TABLE (Snapshot per member)
create table if not exists public.settlement_items (
    id uuid primary key default gen_random_uuid(),
    settlement_id uuid not null references public.monthly_settlements(id) on delete cascade,
    member_id uuid not null references public.mess_members(id) on delete cascade,
    meal_units numeric(8,2) not null default 0.00,
    meal_cost numeric(12,2) not null default 0.00,
    shared_cost numeric(12,2) not null default 0.00,
    individual_cost numeric(12,2) not null default 0.00,
    total_deposits numeric(12,2) not null default 0.00,
    net_balance numeric(12,2) not null default 0.00,
    created_at timestamptz default now(),
    unique(settlement_id, member_id)
);

-- 11. AUDIT LOGS TABLE
create table if not exists public.audit_logs (
    id uuid primary key default gen_random_uuid(),
    mess_id uuid not null references public.messes(id) on delete cascade,
    user_id uuid references public.profiles(id) on delete set null,
    action text not null,
    entity_type text not null,
    entity_id text,
    details jsonb,
    created_at timestamptz default now()
);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

alter table public.profiles enable row level security;
alter table public.messes enable row level security;
alter table public.mess_members enable row level security;
alter table public.meal_entries enable row level security;
alter table public.expense_categories enable row level security;
alter table public.expenses enable row level security;
alter table public.deposits enable row level security;
alter table public.monthly_settlements enable row level security;
alter table public.settlement_items enable row level security;
alter table public.audit_logs enable row level security;

-- Helper functions for checking membership & role
create or replace function public.is_member_of_mess(m_id uuid)
returns boolean as $$
    select exists (
        select 1 from public.mess_members
        where mess_id = m_id
          and user_id = auth.uid()
          and status = 'active'
    );
$$ language sql security definer;

create or replace function public.is_manager_of_mess(m_id uuid)
returns boolean as $$
    select exists (
        select 1 from public.mess_members
        where mess_id = m_id
          and user_id = auth.uid()
          and role = 'manager'
          and status = 'active'
    );
$$ language sql security definer;

-- Profiles: Anyone authenticated can view profiles, users can update own profile
create policy "Users can view all member profiles"
    on public.profiles for select
    using (auth.uid() is not null);

create policy "Users can update own profile"
    on public.profiles for update
    using (auth.uid() = id);

-- Messes:
create policy "Members can view their mess"
    on public.messes for select
    using (public.is_member_of_mess(id));

create policy "Authenticated users can create a mess"
    on public.messes for insert
    with check (auth.uid() is not null);

create policy "Managers can update mess details"
    on public.messes for update
    using (public.is_manager_of_mess(id));

-- Mess Members:
create policy "Members can view roster of their mess"
    on public.mess_members for select
    using (public.is_member_of_mess(mess_id));

create policy "Managers can insert members"
    on public.mess_members for insert
    with check (public.is_manager_of_mess(mess_id) or auth.uid() = user_id);

create policy "Managers can update members"
    on public.mess_members for update
    using (public.is_manager_of_mess(mess_id));

-- Meal Entries:
create policy "Members can view meal entries"
    on public.meal_entries for select
    using (public.is_member_of_mess(mess_id));

create policy "Managers can insert meal entries"
    on public.meal_entries for insert
    with check (public.is_manager_of_mess(mess_id));

create policy "Managers can update meal entries"
    on public.meal_entries for update
    using (public.is_manager_of_mess(mess_id));

create policy "Managers can delete meal entries"
    on public.meal_entries for delete
    using (public.is_manager_of_mess(mess_id));

-- Expenses:
create policy "Members can view expenses"
    on public.expenses for select
    using (public.is_member_of_mess(mess_id));

create policy "Managers can insert expenses"
    on public.expenses for insert
    with check (public.is_manager_of_mess(mess_id));

create policy "Managers can update expenses"
    on public.expenses for update
    using (public.is_manager_of_mess(mess_id));

create policy "Managers can delete expenses"
    on public.expenses for delete
    using (public.is_manager_of_mess(mess_id));

-- Expense Categories:
create policy "Members can view expense categories"
    on public.expense_categories for select
    using (public.is_member_of_mess(mess_id));

create policy "Managers can manage categories"
    on public.expense_categories for all
    using (public.is_manager_of_mess(mess_id));

-- Deposits:
create policy "Members can view deposits"
    on public.deposits for select
    using (public.is_member_of_mess(mess_id));

create policy "Managers can insert deposits"
    on public.deposits for insert
    with check (public.is_manager_of_mess(mess_id));

create policy "Managers can update deposits"
    on public.deposits for update
    using (public.is_manager_of_mess(mess_id));

create policy "Managers can delete deposits"
    on public.deposits for delete
    using (public.is_manager_of_mess(mess_id));

-- Monthly Settlements & Items:
create policy "Members can view settlements"
    on public.monthly_settlements for select
    using (public.is_member_of_mess(mess_id));

create policy "Managers can manage settlements"
    on public.monthly_settlements for all
    using (public.is_manager_of_mess(mess_id));

create policy "Members can view settlement items"
    on public.settlement_items for select
    using (exists (
        select 1 from public.monthly_settlements s
        where s.id = settlement_items.settlement_id
          and public.is_member_of_mess(s.mess_id)
    ));

create policy "Managers can insert settlement items"
    on public.settlement_items for insert
    with check (exists (
        select 1 from public.monthly_settlements s
        where s.id = settlement_items.settlement_id
          and public.is_manager_of_mess(s.mess_id)
    ));

-- Audit Logs:
create policy "Members can view audit logs"
    on public.audit_logs for select
    using (public.is_member_of_mess(mess_id));

create policy "Authenticated users can insert audit logs"
    on public.audit_logs for insert
    with check (public.is_member_of_mess(mess_id));
