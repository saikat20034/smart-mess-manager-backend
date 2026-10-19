# Smart Mess Manager - Backend API & Database

Production-ready backend API service and Supabase relational database schema with Row Level Security (RLS) for the **Smart Mess Manager** web application.

## 🚀 Features

- **Express.js API**: Lightweight, robust REST endpoints with Helmet security, CORS, and JSON logging.
- **Supabase PostgreSQL Schema (`supabase/schema.sql`)**:
  - Relational tables for messes, members, daily meal entries, bazar expenses, member deposits, monthly settlements, settlement items, and audit logs.
  - Granular **Row Level Security (RLS)** ensuring isolated mess data and restricting financial adjustments to mess managers.
  - Seed SQL (`supabase/seed.sql`) containing a realistic Bangladeshi student mess (*Padma Hall Mess, DU*) with 5 members, bKash deposits, bazar expenses, and meal entries.
- **Calculation Verification Endpoints**:
  - `POST /api/calculations/meal-rate`
  - `POST /api/calculations/settlement`
- **Unit Test Suite**: Zero-dependency automated tests testing calculation precision, rounding, and edge cases.

## 📦 Setup & Running

```bash
# 1. Install dependencies
npm install

# 2. Run unit tests
npm test

# 3. Start development server
npm run dev
```

API will be live at `http://localhost:5000/api/health`.

## 🗄️ Supabase Database Setup

1. Create a project at [supabase.com](https://supabase.com).
2. Go to the **SQL Editor** in your Supabase dashboard.
3. Open `supabase/schema.sql` and run the script to create tables and RLS policies.
4. (Optional) Run `supabase/seed.sql` to populate sample Bangladeshi mess records.
