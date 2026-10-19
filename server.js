import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5000;

// Security and middleware
app.use(helmet());
app.use(cors({
  origin: '*', // Allow frontend development server
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(morgan('dev'));

// Supabase client initialization (optional if keys provided)
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';

export const supabase = (supabaseUrl && supabaseServiceKey)
  ? createClient(supabaseUrl, supabaseServiceKey)
  : null;

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    app: 'Smart Mess Manager API',
    version: '1.0.0',
    currency: 'BDT (৳)',
    supabaseConnected: Boolean(supabase),
    timestamp: new Date().toISOString()
  });
});

// Calculation verification endpoint: Meal Rate
app.post('/api/calculations/meal-rate', (req, res) => {
  try {
    const { totalMealExpenses, totalMealUnits } = req.body;
    const expenses = Number(totalMealExpenses) || 0;
    const meals = Number(totalMealUnits) || 0;

    if (meals <= 0) {
      return res.json({
        mealRate: 0,
        formattedRate: '৳ 0.00',
        note: 'Zero meals recorded. Meal rate is 0.00'
      });
    }

    const rate = expenses / meals;
    const roundedRate = Math.round((rate + Number.EPSILON) * 100) / 100;

    return res.json({
      totalMealExpenses: expenses,
      totalMealUnits: meals,
      rawRate: rate,
      mealRate: roundedRate,
      formattedRate: `৳ ${roundedRate.toFixed(2)}`
    });
  } catch (error) {
    return res.status(400).json({ error: error.message });
  }
});

// Calculation verification endpoint: Monthly Settlement Summary
app.post('/api/calculations/settlement', (req, res) => {
  try {
    const { members = [], meals = [], expenses = [], deposits = [], settings = {} } = req.body;

    const breakfastWeight = Number(settings.breakfast_unit ?? 0.5);
    const lunchWeight = Number(settings.lunch_unit ?? 1.0);
    const dinnerWeight = Number(settings.dinner_unit ?? 1.0);

    // 1. Calculate meal units per member
    const memberMealUnits = {};
    members.forEach(m => { memberMealUnits[m.id] = 0; });

    meals.forEach(entry => {
      const b = Number(entry.breakfast || 0) * breakfastWeight;
      const l = Number(entry.lunch || 0) * lunchWeight;
      const d = Number(entry.dinner || 0) * dinnerWeight;
      const units = b + l + d;
      if (memberMealUnits[entry.member_id] !== undefined) {
        memberMealUnits[entry.member_id] += units;
      }
    });

    const totalMealUnits = Object.values(memberMealUnits).reduce((sum, u) => sum + u, 0);

    // 2. Separate expenses: meal-related (bazar) vs shared overhead
    let totalMealExpenses = 0;
    let totalSharedExpenses = 0;

    expenses.forEach(exp => {
      const amt = Number(exp.amount || 0);
      if (exp.is_meal_related !== false) {
        totalMealExpenses += amt;
      } else {
        totalSharedExpenses += amt;
      }
    });

    // 3. Compute meal rate
    const mealRate = totalMealUnits > 0
      ? Math.round(((totalMealExpenses / totalMealUnits) + Number.EPSILON) * 10000) / 10000
      : 0;

    // 4. Shared cost allocation (equal policy)
    const activeMembers = members.filter(m => m.status === 'active' || !m.status);
    const memberCount = Math.max(activeMembers.length, 1);
    const sharedCostPerMember = Math.round(((totalSharedExpenses / memberCount) + Number.EPSILON) * 100) / 100;

    // 5. Total deposits per member
    const memberDeposits = {};
    members.forEach(m => { memberDeposits[m.id] = 0; });
    deposits.forEach(dep => {
      if (memberDeposits[dep.member_id] !== undefined) {
        memberDeposits[dep.member_id] += Number(dep.amount || 0);
      }
    });

    // 6. Build individual member settlement breakdown
    const settlementItems = members.map(member => {
      const units = Math.round((memberMealUnits[member.id] || 0) * 100) / 100;
      const mealCost = Math.round(((units * mealRate) + Number.EPSILON) * 100) / 100;
      const sharedCost = member.status === 'inactive' ? 0 : sharedCostPerMember;
      const totalCost = mealCost + sharedCost;
      const totalDeposit = memberDeposits[member.id] || 0;
      // Net balance: positive = credit/surplus (mess owes member), negative = due/deficit (member owes mess)
      const netBalance = Math.round(((totalDeposit - totalCost) + Number.EPSILON) * 100) / 100;

      return {
        memberId: member.id,
        name: member.name,
        roomNumber: member.room_number,
        mealUnits: units,
        mealCost,
        sharedCost,
        totalCost,
        totalDeposits: totalDeposit,
        netBalance,
        status: netBalance >= 0 ? 'Credit' : 'Due'
      };
    });

    return res.json({
      summary: {
        totalMealUnits: Math.round(totalMealUnits * 100) / 100,
        totalMealExpenses,
        totalSharedExpenses,
        totalExpenses: totalMealExpenses + totalSharedExpenses,
        totalDeposits: Object.values(memberDeposits).reduce((a, b) => a + b, 0),
        mealRate: Math.round(mealRate * 100) / 100,
        preciseMealRate: mealRate,
        activeMemberCount: activeMembers.length
      },
      items: settlementItems
    });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

// Start listening
if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`🚀 Smart Mess Manager Backend running on port ${PORT}`);
    console.log(`🌐 Health check: http://localhost:${PORT}/api/health`);
  });
}

export default app;
