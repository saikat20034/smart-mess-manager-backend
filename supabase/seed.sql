-- ==============================================================================
-- SMART MESS MANAGER - SEED DATA (BANGLADESHI UNIVERSITY MESS DEMO)
-- Mess: "Padma Hall Mess, DU"
-- Currency: BDT (৳)
-- ==============================================================================

-- 1. Sample Mess
insert into public.messes (id, name, address, currency, invite_code, month_start_day, breakfast_unit, lunch_unit, dinner_unit)
values (
    'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab',
    'Padma Hall Mess (Dhaka University)',
    'Room 402, Shahidullah Hall Extension, Curzon Hall, Dhaka',
    'BDT',
    'PADMA2026',
    1,
    0.50,
    1.00,
    1.00
) on conflict do nothing;

-- 2. Expense Categories
insert into public.expense_categories (id, mess_id, name, is_meal_related, icon) values
('c1111111-1111-1111-1111-111111111111', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Groceries & Bazar', true, 'shopping-bag'),
('c2222222-2222-2222-2222-222222222222', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Meat & Fish', true, 'fish'),
('c3333333-3333-3333-3333-333333333333', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Cook (Khala) Salary', false, 'user-check'),
('c4444444-4444-4444-4444-444444444444', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Gas & Cooking Cylinder', false, 'flame'),
('c5555555-5555-5555-5555-555555555555', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'High-Speed WiFi', false, 'wifi'),
('c6666666-6666-6666-6666-666666666666', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Cleaning & Utilities', false, 'sparkles')
on conflict do nothing;

-- 3. Sample Mess Members
insert into public.mess_members (id, mess_id, name, phone, email, room_number, role, status, joined_at) values
('m1111111-1111-1111-1111-111111111111', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Tanvir Ahmed (Manager)', '01711223344', 'tanvir@du.ac.bd', '402-A', 'manager', 'active', '2026-01-01'),
('m2222222-2222-2222-2222-222222222222', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Arif Hossain', '01822334455', 'arif@du.ac.bd', '402-B', 'member', 'active', '2026-01-01'),
('m3333333-3333-3333-3333-333333333333', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Rakib Hasan', '01933445566', 'rakib@du.ac.bd', '402-C', 'member', 'active', '2026-01-05'),
('m4444444-4444-4444-4444-444444444444', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Sakibul Islam', '01644556677', 'sakib@du.ac.bd', '402-D', 'member', 'active', '2026-01-10'),
('m5555555-5555-5555-5555-555555555555', 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'Naimur Rahman', '01555667788', 'naim@du.ac.bd', '402-E', 'member', 'active', '2026-02-01')
on conflict do nothing;

-- 4. Sample Deposits
insert into public.deposits (mess_id, member_id, amount, date, payment_method, transaction_ref, notes) values
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'm1111111-1111-1111-1111-111111111111', 4000.00, '2026-10-01', 'Cash', 'MANAGER-ADV-01', 'Initial monthly deposit'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'm2222222-2222-2222-2222-222222222222', 3500.00, '2026-10-02', 'bKash', 'BKASH9X28381', 'October advance'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'm3333333-3333-3333-3333-333333333333', 3500.00, '2026-10-02', 'Nagad', 'NGD77219482', 'Monthly mess advance'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'm4444444-4444-4444-4444-444444444444', 3000.00, '2026-10-03', 'bKash', 'BKASH1928471', 'Advance deposit'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'm5555555-5555-5555-5555-555555555555', 2500.00, '2026-10-04', 'Cash', 'CASH-REC-02', 'Deposit given to manager')
on conflict do nothing;

-- 5. Sample Expenses
insert into public.expenses (mess_id, category_id, title, amount, date, paid_by_member_id, is_meal_related, notes) values
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'c1111111-1111-1111-1111-111111111111', 'Miniket Rice (25kg Bag) & Spices', 2150.00, '2026-10-02', 'm1111111-1111-1111-1111-111111111111', true, 'Purchased from Karwan Bazar'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'c2222222-2222-2222-2222-222222222222', 'Broiler Chicken (4kg) & Eggs (2 Dozen)', 1280.00, '2026-10-04', 'm2222222-2222-2222-2222-222222222222', true, 'Ananda Bazar purchase'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'c1111111-1111-1111-1111-111111111111', 'Fresh Vegetables, Onion, Garlic & Green Chili', 640.00, '2026-10-07', 'm3333333-3333-3333-3333-333333333333', true, 'Palashi Bazar morning shopping'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'c2222222-2222-2222-2222-222222222222', 'Rui Fish (3kg) & Mustard Oil (1L)', 1150.00, '2026-10-10', 'm1111111-1111-1111-1111-111111111111', true, 'Fresh fish from New Market'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'c3333333-3333-3333-3333-333333333333', 'Cook (Khala) Monthly Bill', 2500.00, '2026-10-10', 'm1111111-1111-1111-1111-111111111111', false, 'Monthly salary paid to Khala'),
('a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab', 'c5555555-5555-5555-5555-555555555555', 'Shared WiFi Bill (50 Mbps)', 800.00, '2026-10-05', 'm4444444-4444-4444-4444-444444444444', false, 'Paid via bKash to ISP provider')
on conflict do nothing;
