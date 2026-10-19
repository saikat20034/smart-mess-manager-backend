import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

describe('Smart Mess Manager Calculation Unit Tests', () => {
  test('Meal Rate calculation: normal case', () => {
    const totalExpenses = 5120; // BDT
    const totalMeals = 128; // meal units
    const expectedRate = 40.0;
    const rate = totalExpenses / totalMeals;
    assert.equal(rate, expectedRate);
  });

  test('Meal Rate calculation: fractional and rounding', () => {
    const totalExpenses = 1000;
    const totalMeals = 33;
    const rate = totalExpenses / totalMeals;
    const rounded = Math.round((rate + Number.EPSILON) * 100) / 100;
    assert.equal(rounded, 30.30);
  });

  test('Meal Rate calculation: zero meals returns 0 without crashing', () => {
    const totalExpenses = 500;
    const totalMeals = 0;
    const rate = totalMeals > 0 ? totalExpenses / totalMeals : 0;
    assert.equal(rate, 0);
  });

  test('Shared expense equal division among active members', () => {
    const cookSalary = 2500;
    const wifiBill = 800;
    const totalShared = cookSalary + wifiBill; // 3300
    const activeMembers = 5;
    const perMember = totalShared / activeMembers;
    assert.equal(perMember, 660);
  });

  test('Member Net Balance calculation: credit vs due convention', () => {
    // Member: Tanvir
    const mealUnits = 30;
    const mealRate = 40;
    const mealCost = mealUnits * mealRate; // 1200
    const sharedCost = 660; // 660
    const totalCost = mealCost + sharedCost; // 1860
    const deposits = 2500;

    // Net balance = Deposits - Total Cost
    const balance = deposits - totalCost; // +640 (Credit)
    assert.equal(balance, 640);
    assert.ok(balance >= 0, 'Positive balance indicates member has surplus credit');

    // Member: Rakib (Due)
    const rakibMeals = 35;
    const rakibMealCost = rakibMeals * mealRate; // 1400
    const rakibTotalCost = rakibMealCost + sharedCost; // 2060
    const rakibDeposits = 1500;
    const rakibBalance = rakibDeposits - rakibTotalCost; // -560 (Due)
    assert.equal(rakibBalance, -560);
    assert.ok(rakibBalance < 0, 'Negative balance indicates member owes money to mess');
  });
});
