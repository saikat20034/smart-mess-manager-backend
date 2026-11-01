-- ==============================================================================
-- SMART MESS MANAGER - DATABASE SCHEMA & ROW LEVEL SECURITY (RLS) POLICIES
-- Target: Supabase (PostgreSQL 15+)
-- Currency: Bangladeshi Taka (BDT ৳)
-- ==============================================================================

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";

-- 2. PROFILES TABLE (Linked with Supabase Auth users)
create table if not exists public.profiles (
    id text primary key default gen_random_uuid()::text,
    user_id uuid references auth.users(id) on delete cascade,
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
    insert into public.profiles (id, user_id, full_name, phone, avatar_url)
    values (
        new.id::text,
        new.id,
        coalesce(new.raw_user_meta_data->>'full_name', 'Mess Member'),
        new.raw_user_meta_data->>'phone',
        new.raw_user_meta_data->>'avatar_url'
    )
    on conflict (id) do nothing;
    return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- 3. MESSES TABLE
create table if not exists public.messes (
    id text primary key default gen_random_uuid()::text,
    name text not null,
    address text,
    currency text not null default 'BDT',
    invite_code text unique not null,
    month_start_day int not null default 1 check (month_start_day between 1 and 28),
    breakfast_unit numeric(3,2) not null default 1.00,
    lunch_unit numeric(3,2) not null default 1.00,
    dinner_unit numeric(3,2) not null default 1.00,
    shared_expense_policy text not null default 'equal' check (shared_expense_policy in ('equal', 'per_meal')),
    created_by text references public.profiles(id) on delete set null,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- 4. MESS MEMBERS TABLE
create table if not exists public.mess_members (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    user_id text references public.profiles(id) on delete set null,
    name text not null,
    phone text,
    email text,
    room_number text,
    role text not null default 'member' check (role in ('manager', 'member')),
    status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
    avatar text,
    joined_at date not null default current_date,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Index for membership lookups
create index if not exists idx_mess_members_mess_id on public.mess_members(mess_id);
create index if not exists idx_mess_members_email on public.mess_members(email);

-- 5. MEAL ENTRIES TABLE
create table if not exists public.meal_entries (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    member_id text not null references public.mess_members(id) on delete cascade,
    date date not null,
    breakfast numeric(3,2) not null default 0.00 check (breakfast >= 0),
    lunch numeric(3,2) not null default 0.00 check (lunch >= 0),
    dinner numeric(3,2) not null default 0.00 check (dinner >= 0),
    total_units numeric(4,2) not null default 0.00 check (total_units >= 0),
    notes text,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(mess_id, member_id, date)
);

create index if not exists idx_meal_entries_date on public.meal_entries(mess_id, date);
create index if not exists idx_meal_entries_member on public.meal_entries(member_id, date);

-- 6. EXPENSE CATEGORIES TABLE
create table if not exists public.expense_categories (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    name text not null,
    is_meal_related boolean not null default false,
    icon text default 'shopping-bag',
    created_at timestamptz default now()
);

-- 7. EXPENSES TABLE (Bazar & Shared Overhead)
create table if not exists public.expenses (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    category_id text references public.expense_categories(id) on delete set null,
    title text not null,
    amount numeric(12,2) not null check (amount > 0),
    date date not null default current_date,
    paid_by_member_id text references public.mess_members(id) on delete set null,
    paid_by_name text,
    is_meal_related boolean not null default true,
    receipt_url text,
    notes text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_expenses_date on public.expenses(mess_id, date);
create index if not exists idx_expenses_category on public.expenses(category_id);

-- 8. DEPOSITS TABLE (Member Payments)
create table if not exists public.deposits (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    member_id text not null references public.mess_members(id) on delete cascade,
    member_name text,
    amount numeric(12,2) not null check (amount > 0),
    date date not null default current_date,
    payment_method text not null check (payment_method in ('bKash', 'Nagad', 'Rocket', 'Cash', 'Bank', 'Other')),
    transaction_ref text,
    notes text,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create index if not exists idx_deposits_member on public.deposits(member_id);
create index if not exists idx_deposits_date on public.deposits(mess_id, date);

-- 9. MONTHLY SETTLEMENTS TABLE
create table if not exists public.monthly_settlements (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    month int not null check (month between 1 and 12),
    year int not null check (year >= 2020),
    month_year text,
    total_meal_units numeric(10,2) not null default 0.00,
    total_meal_expenses numeric(12,2) not null default 0.00,
    total_shared_expenses numeric(12,2) not null default 0.00,
    meal_rate numeric(8,4) not null default 0.0000,
    total_deposits numeric(12,2) not null default 0.00,
    cash_in_hand numeric(12,2) not null default 0.00,
    outstanding_dues numeric(12,2) not null default 0.00,
    total_credits numeric(12,2) not null default 0.00,
    is_finalized boolean not null default false,
    finalized_by_name text,
    finalized_at timestamptz,
    notes text,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    unique(mess_id, month, year)
);

-- 10. SETTLEMENT ITEMS TABLE (Snapshot per member)
create table if not exists public.settlement_items (
    id text primary key default gen_random_uuid()::text,
    settlement_id text not null references public.monthly_settlements(id) on delete cascade,
    member_id text not null references public.mess_members(id) on delete cascade,
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
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    user_id text,
    action text not null,
    title text,
    details text,
    timestamp timestamptz default now()
);

-- 12. BAZAR ITEMS TABLE (Checklist)
create table if not exists public.bazar_items (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    name text not null,
    quantity text,
    estimated_cost numeric(12,2) default 0.00,
    completed boolean not null default false,
    buyer_name text,
    created_at timestamptz default now()
);

-- 13. BAZAR SCHEDULES TABLE (Duty roster)
create table if not exists public.bazar_schedules (
    id text primary key default gen_random_uuid()::text,
    mess_id text not null references public.messes(id) on delete cascade,
    date date not null,
    member_id text references public.mess_members(id) on delete cascade,
    member_name text not null,
    status text not null default 'Upcoming' check (status in ('Upcoming', 'Completed', 'Swapped', 'Missed')),
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
alter table public.bazar_items enable row level security;
alter table public.bazar_schedules enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles:
create policy "Allow all users to view profiles" on public.profiles for select using (true);
create policy "Allow users to insert/update profile" on public.profiles for all using (true) with check (true);

-- Messes:
create policy "Allow public to lookup and view messes" on public.messes for select using (true);
create policy "Allow anyone to create a mess" on public.messes for insert with check (true);
create policy "Allow mess updates" on public.messes for update using (true);
create policy "Allow mess deletion" on public.messes for delete using (true);

-- Mess Members:
create policy "Allow viewing mess members" on public.mess_members for select using (true);
create policy "Allow inserting mess members" on public.mess_members for insert with check (true);
create policy "Allow updating mess members" on public.mess_members for update using (true);
create policy "Allow deleting mess members" on public.mess_members for delete using (true);

-- Meal Entries:
create policy "Allow viewing meal entries" on public.meal_entries for select using (true);
create policy "Allow inserting meal entries" on public.meal_entries for insert with check (true);
create policy "Allow updating meal entries" on public.meal_entries for update using (true);
create policy "Allow deleting meal entries" on public.meal_entries for delete using (true);

-- Expenses & Categories:
create policy "Allow viewing expense categories" on public.expense_categories for select using (true);
create policy "Allow managing expense categories" on public.expense_categories for all using (true);

create policy "Allow viewing expenses" on public.expenses for select using (true);
create policy "Allow inserting expenses" on public.expenses for insert with check (true);
create policy "Allow updating expenses" on public.expenses for update using (true);
create policy "Allow deleting expenses" on public.expenses for delete using (true);

-- Deposits:
create policy "Allow viewing deposits" on public.deposits for select using (true);
create policy "Allow inserting deposits" on public.deposits for insert with check (true);
create policy "Allow updating deposits" on public.deposits for update using (true);
create policy "Allow deleting deposits" on public.deposits for delete using (true);

-- Settlements:
create policy "Allow viewing settlements" on public.monthly_settlements for select using (true);
create policy "Allow managing settlements" on public.monthly_settlements for all using (true);

create policy "Allow viewing settlement items" on public.settlement_items for select using (true);
create policy "Allow managing settlement items" on public.settlement_items for all using (true);

-- Bazar Items & Schedules:
create policy "Allow viewing bazar items" on public.bazar_items for select using (true);
create policy "Allow managing bazar items" on public.bazar_items for all using (true);

create policy "Allow viewing bazar schedules" on public.bazar_schedules for select using (true);
create policy "Allow managing bazar schedules" on public.bazar_schedules for all using (true);

-- Audit Logs:
create policy "Allow viewing audit logs" on public.audit_logs for select using (true);
create policy "Allow inserting audit logs" on public.audit_logs for insert with check (true);
