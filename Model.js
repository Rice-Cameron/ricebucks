// Business logic and data management for the Budget Tracker plugin

.pragma library

// General default starter categories for new installations
var defaultCategories = [
  "Housing",
  "Groceries",
  "Dining Out",
  "Transportation",
  "Utilities",
  "Entertainment",
  "Other"
];

function defaultState() {
  return {
    version: 1,
    income: 0,
    savingsPercent: 20,
    categories: defaultCategories.slice(),
    expenses: []
  };
}

function parseState(raw) {
  if (!raw || typeof raw !== "string" || raw.trim() === "") {
    return defaultState();
  }
  try {
    var parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return defaultState();
    
    var state = defaultState();
    if (typeof parsed.income === "number" && !isNaN(parsed.income)) {
      state.income = Math.max(0, parsed.income);
    }
    if (typeof parsed.savingsPercent === "number" && !isNaN(parsed.savingsPercent)) {
      state.savingsPercent = Math.max(0, Math.min(100, parsed.savingsPercent));
    }
    if (Array.isArray(parsed.categories) && parsed.categories.length > 0) {
      state.categories = parsed.categories.filter(function(c) {
        return typeof c === "string" && c.trim() !== "";
      });
    }
    if (Array.isArray(parsed.expenses)) {
      state.expenses = parsed.expenses.filter(function(e) {
        return e && typeof e === "object" && typeof e.amount === "number" && !isNaN(e.amount);
      });
    }
    return state;
  } catch (err) {
    console.warn("Budget Model: failed to parse state JSON:", err);
    return defaultState();
  }
}

function currentMonthKey() {
  var now = new Date();
  var year = now.getFullYear();
  var month = String(now.getMonth() + 1).padStart(2, "0");
  return year + "-" + month;
}

function monthLabel(monthKey) {
  var parts = String(monthKey || "").split("-");
  if (parts.length < 2) return currentMonthKey();
  var year = parseInt(parts[0], 10);
  var monthIdx = parseInt(parts[1], 10) - 1;
  var months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];
  return (months[monthIdx] || parts[1]) + " " + year;
}

function savingsAmount(income, savingsPercent) {
  var inc = Number(income) || 0;
  var pct = Number(savingsPercent) || 0;
  return Math.round(inc * (pct / 100) * 100) / 100;
}

function filterExpensesByMonth(expenses, monthKey) {
  if (!Array.isArray(expenses)) return [];
  var target = monthKey || currentMonthKey();
  return expenses.filter(function(e) {
    if (!e || !e.date) return false;
    return String(e.date).indexOf(target) === 0;
  });
}

function totalExpenses(expenses) {
  if (!Array.isArray(expenses)) return 0;
  var sum = 0;
  for (var i = 0; i < expenses.length; i++) {
    var amt = Number(expenses[i].amount) || 0;
    sum += amt;
  }
  return Math.round(sum * 100) / 100;
}

function remainingBudget(income, savingsPercent, expenses) {
  var inc = Number(income) || 0;
  var target = savingsAmount(inc, savingsPercent);
  var spent = totalExpenses(expenses);
  return Math.round((inc - target - spent) * 100) / 100;
}

function categoryTotals(expenses, allCategories) {
  var totals = {};
  var counts = {};
  var cats = Array.isArray(allCategories) ? allCategories.slice() : defaultCategories.slice();

  for (var i = 0; i < cats.length; i++) {
    totals[cats[i]] = 0;
    counts[cats[i]] = 0;
  }

  var totalSpent = 0;
  if (Array.isArray(expenses)) {
    for (var j = 0; j < expenses.length; j++) {
      var exp = expenses[j];
      var amt = Number(exp.amount) || 0;
      var cat = String(exp.category || "Other").trim();
      if (!totals.hasOwnProperty(cat)) {
        totals[cat] = 0;
        counts[cat] = 0;
        cats.push(cat);
      }
      totals[cat] += amt;
      counts[cat] += 1;
      totalSpent += amt;
    }
  }

  var result = [];
  for (var k = 0; k < cats.length; k++) {
    var name = cats[k];
    var amt = totals[name] || 0;
    var pct = totalSpent > 0 ? (amt / totalSpent) * 100 : 0;
    result.push({
      category: name,
      total: Math.round(amt * 100) / 100,
      percent: Math.round(pct * 10) / 10,
      count: counts[name] || 0
    });
  }

  // Sort: categories with spending first (sorted descending by total), then unused categories
  result.sort(function(a, b) {
    if (a.total > 0 && b.total > 0) return b.total - a.total;
    if (a.total > 0) return -1;
    if (b.total > 0) return 1;
    return 0;
  });

  return result;
}

function formatMoney(amount) {
  var val = Number(amount);
  if (!isFinite(val)) val = 0;
  var sign = val < 0 ? "-" : "";
  val = Math.abs(val);
  return sign + "$" + val.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function formatShortDate(isoString) {
  if (!isoString) return "";
  try {
    var d = new Date(isoString);
    if (isNaN(d.getTime())) return String(isoString);
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var m = months[d.getMonth()];
    var day = d.getDate();
    var h = d.getHours();
    var min = String(d.getMinutes()).padStart(2, "0");
    var ampm = h >= 12 ? "PM" : "AM";
    h = h % 12 || 12;
    return m + " " + day + " " + h + ":" + min + " " + ampm;
  } catch (e) {
    return String(isoString);
  }
}

function createExpense(amount, category, note) {
  var amt = parseFloat(amount);
  if (!isFinite(amt) || amt <= 0) return null;
  return {
    id: String(Date.now()) + "-" + Math.floor(Math.random() * 10000),
    amount: Math.round(amt * 100) / 100,
    category: String(category || "Other").trim(),
    note: String(note || "").trim(),
    date: new Date().toISOString()
  };
}

// Category Management Functions
function addCategory(categories, name) {
  if (!Array.isArray(categories)) categories = [];
  var trimmed = String(name || "").trim();
  if (!trimmed) return { ok: false, error: "Category name cannot be empty" };
  for (var i = 0; i < categories.length; i++) {
    if (categories[i].toLowerCase() === trimmed.toLowerCase()) {
      return { ok: false, error: "Category already exists" };
    }
  }
  var updated = categories.slice();
  updated.push(trimmed);
  return { ok: true, categories: updated };
}

function renameCategory(categories, expenses, oldName, newName) {
  if (!Array.isArray(categories)) return { ok: false, error: "Invalid categories" };
  var from = String(oldName || "").trim();
  var to = String(newName || "").trim();
  if (!from || !to) return { ok: false, error: "Names cannot be empty" };
  if (from === to) return { ok: true, categories: categories, expenses: expenses };

  var fromIdx = -1;
  for (var i = 0; i < categories.length; i++) {
    if (categories[i] === from) { fromIdx = i; break; }
  }
  if (fromIdx === -1) return { ok: false, error: "Category not found: " + from };

  // Check if newName already exists (case-insensitive)
  for (var j = 0; j < categories.length; j++) {
    if (j !== fromIdx && categories[j].toLowerCase() === to.toLowerCase()) {
      return { ok: false, error: "Category already exists: " + to };
    }
  }

  var updatedCats = categories.slice();
  updatedCats[fromIdx] = to;

  var updatedExps = Array.isArray(expenses) ? expenses.map(function(e) {
    if (e && e.category === from) {
      var copy = Object.assign({}, e);
      copy.category = to;
      return copy;
    }
    return e;
  }) : [];

  return { ok: true, categories: updatedCats, expenses: updatedExps };
}

function deleteCategory(categories, expenses, name) {
  if (!Array.isArray(categories)) return { ok: false, error: "Invalid categories" };
  var target = String(name || "").trim();
  if (!target) return { ok: false, error: "Category name cannot be empty" };

  var targetIdx = categories.indexOf(target);
  if (targetIdx === -1) return { ok: false, error: "Category not found: " + target };

  if (categories.length <= 1) {
    return { ok: false, error: "Cannot delete the only remaining category" };
  }

  var fallback = "Other";
  var updatedCats = categories.filter(function(c) { return c !== target; });

  // If we deleted something other than "Other", make sure "Other" exists as a fallback
  if (target !== fallback && updatedCats.indexOf(fallback) === -1) {
    updatedCats.push(fallback);
  } else if (target === fallback) {
    fallback = updatedCats[0];
  }

  // Reassign affected expenses
  var updatedExps = Array.isArray(expenses) ? expenses.map(function(e) {
    if (e && e.category === target) {
      var copy = Object.assign({}, e);
      copy.category = fallback;
      return copy;
    }
    return e;
  }) : [];

  return { ok: true, categories: updatedCats, expenses: updatedExps, fallback: fallback };
}

function moveCategory(categories, fromIndex, toIndex) {
  if (!Array.isArray(categories)) return categories;
  var from = Math.max(0, Math.min(categories.length - 1, fromIndex));
  var to = Math.max(0, Math.min(categories.length - 1, toIndex));
  if (from === to) return categories;
  var updated = categories.slice();
  var item = updated.splice(from, 1)[0];
  updated.splice(to, 0, item);
  return updated;
}
