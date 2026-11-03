import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import nodemailer from 'nodemailer';
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

// ==============================================================================
// EMAIL VERIFICATION SERVICE (GMAIL SMTP - SAME ID & APP PASS)
// ==============================================================================
const otpStore = new Map();

const emailUser = (process.env.EMAIL_USER || 'mazharulislamsaikat2000@gmail.com').trim();
const emailPass = (process.env.EMAIL_PASS || 'hvstfiabvybrjemw').replace(/\s+/g, '').trim();

let cachedTransporter = null;
function getMailTransporter() {
  if (!cachedTransporter) {
    cachedTransporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: emailUser,
        pass: emailPass
      },
      connectionTimeout: 10000,
      greetingTimeout: 10000,
      socketTimeout: 15000
    });
  }
  return cachedTransporter;
}

// 1. Send 6-digit OTP verification email
app.post('/api/auth/send-verification-otp', async (req, res) => {
  try {
    const { email, name } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, error: 'দয়া করে একটি সঠিক ইমেইল এড্রেস লিখুন' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const recipientName = (name || 'মেস মেম্বার').trim();

    // Generate cryptographic-style 6-digit OTP code
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    otpStore.set(cleanEmail, {
      code: otpCode,
      expires: expiresAt,
      name: recipientName
    });

    const transporter = getMailTransporter();

    const mailOptions = {
      from: `"Smart Mess Manager" <${emailUser}>`,
      to: cleanEmail,
      subject: `Smart Mess Manager - ইমেইল ভেরিফিকেশন কোড: ${otpCode}`,
      text: `হ্যালো ${recipientName},\n\nSmart Mess Manager-এ সাইন আপ করার জন্য আপনাকে ধন্যবাদ।\nআপনার ইমেইল ভেরিফিকেশন কোড: ${otpCode}\n\nএই কোডটি আগামী ১০ মিনিটের জন্য কার্যকর থাকবে।\n\nনিরাপত্তা রক্ষার্থে এটি কারও সাথে শেয়ার করবেন না।`,
      html: `
        <!DOCTYPE html>
        <html lang="bn">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body { margin: 0; padding: 24px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; color: #1e293b; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 20px; overflow: hidden; border: 1px solid #f1f5f9; box-shadow: 0 10px 25px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #e11d48 0%, #f43f5e 100%); padding: 32px 24px; text-align: center; color: #ffffff; }
            .logo-icon { display: inline-block; width: 48px; height: 48px; line-height: 48px; border-radius: 14px; background: rgba(255,255,255,0.2); text-align: center; font-size: 24px; font-weight: 800; color: #ffffff; margin-bottom: 10px; }
            .title { font-size: 22px; font-weight: 800; margin: 0; letter-spacing: -0.5px; }
            .subtitle { font-size: 13px; color: #ffe4e6; margin: 6px 0 0 0; }
            .content { padding: 32px 28px; }
            .greeting { font-size: 16px; font-weight: 700; color: #0f172a; margin-top: 0; margin-bottom: 12px; }
            .desc { font-size: 14px; line-height: 1.6; color: #475569; margin-bottom: 24px; }
            .otp-box { background: #fff1f2; border: 2px dashed #fda4af; border-radius: 16px; padding: 20px; text-align: center; margin: 24px 0; }
            .otp-label { font-size: 11px; font-weight: 700; color: #e11d48; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 6px; }
            .otp-digits { font-family: 'Courier New', Courier, monospace; font-size: 38px; font-weight: 900; letter-spacing: 10px; color: #be123c; }
            .footer-note { font-size: 12px; line-height: 1.6; color: #64748b; margin-top: 20px; }
            .footer { padding: 18px 24px; background-color: #f8fafc; border-top: 1px solid #f1f5f9; font-size: 11px; color: #94a3b8; text-align: center; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="header">
              <div class="logo-icon">S</div>
              <h1 class="title">Smart Mess Manager</h1>
              <p class="subtitle">স্মার্ট মেস ও মিল হিসাব ব্যবস্থাপনা পোর্টাল</p>
            </div>
            <div class="content">
              <h2 class="greeting">আসসালামু আলাইকুম, ${recipientName}!</h2>
              <p class="desc">
                Smart Mess Manager-এ রেজিস্ট্রেশন করার জন্য আপনাকে স্বাগতম। আপনার ইমেইল নিশ্চিত করার জন্য নিচের ৬ ডিজিটের ভেরিফিকেশন ওটিপি কোডটি ব্যবহার করুন:
              </p>
              <div class="otp-box">
                <div class="otp-label">ভেরিফিকেশন ওটিপি কোড</div>
                <div class="otp-digits">${otpCode}</div>
              </div>
              <p class="footer-note">
                ⏱️ এই কোডটি আগামী <strong>১০ মিনিটের</strong> জন্য সক্রিয় থাকবে।<br>
                🔒 এটি একটি ওয়ান-টাইম সিকিউরিটি কোড, কারও সাথে শেয়ার করবেন না।
              </p>
            </div>
            <div class="footer">
              Smart Mess Manager Platform • Contact: mazharulislamsaikat2000@gmail.com
            </div>
          </div>
        </body>
        </html>
      `
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(`📧 [EMAIL OTP SENT] Sent code [${otpCode}] to [${cleanEmail}], messageId: ${info.messageId}`);

    return res.json({
      success: true,
      message: 'ভেরিফিকেশন কোড আপনার ইমেইলে সফলভাবে পাঠানো হয়েছে!',
      previewCode: process.env.NODE_ENV !== 'production' ? otpCode : undefined
    });
  } catch (err) {
    console.error('❌ [EMAIL SEND ERROR]:', err);
    return res.status(500).json({
      success: false,
      error: 'ইমেইল পাঠাতে সমস্যা হয়েছে। দয়া করে ইন্টারনেট ও ইমেইল চেক করুন অথবা পুনরায় চেষ্টা করুন।'
    });
  }
});

// 2. Verify 6-digit OTP code
app.post('/api/auth/verify-otp', (req, res) => {
  try {
    const { email, code } = req.body;
    if (!email || !code) {
      return res.status(400).json({ success: false, error: 'ইমেইল এবং ৬-ডিজিট কোড প্রয়োজন' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const cleanCode = code.toString().trim();

    const record = otpStore.get(cleanEmail);
    if (!record) {
      return res.status(400).json({
        success: false,
        error: 'কোনো ভেরিফিকেশন কোড পাঠানো হয়নি অথবা কোডের মেয়াদ শেষ হয়েছে! অনুগ্রহ করে আবার কোড পাঠান।'
      });
    }

    if (Date.now() > record.expires) {
      otpStore.delete(cleanEmail);
      return res.status(400).json({
        success: false,
        error: 'ভেরিফিকেশন কোডের ১০ মিনিটের মেয়াদ শেষ হয়ে গেছে! অনুগ্রহ করে নতুন কোড পাঠান।'
      });
    }

    if (record.code !== cleanCode) {
      return res.status(400).json({
        success: false,
        error: 'ভুল ভেরিফিকেশন কোড! দয়া করে আপনার ইনবক্স চেক করে সঠিক কোডটি দিন।'
      });
    }

    // Successfully verified!
    otpStore.delete(cleanEmail);
    return res.json({
      success: true,
      verified: true,
      message: 'ইমেইল সফলভাবে ভেরিফাইড হয়েছে!'
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
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
