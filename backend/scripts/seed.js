/**
 * scripts/seed.js — Pre-populate MongoDB with initial data
 *
 * Run with: npm run seed
 *
 * Creates:
 *   - 4 departments (CSE, EEE, BBA, CE)
 *   - 8 courses
 *   - 3 seed users (1 admin, 1 contributor, 1 student)
 *   - 6 sample materials (4 approved, 2 pending)
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const Department = require('../models/Department');
const Course = require('../models/Course');
const User = require('../models/User');
const Material = require('../models/Material');

const DEPARTMENTS = [
  { name: 'Computer Science & Engineering', code: 'CSE', description: 'Department of Computing, Software, and Algorithms.' },
  { name: 'Electrical & Electronic Engineering', code: 'EEE', description: 'Department of Electrical Systems, Signals, and Circuits.' },
  { name: 'Business Administration', code: 'BBA', description: 'Department of Management, Marketing, and Finance.' },
  { name: 'Civil Engineering', code: 'CE', description: 'Department of Structures, Geotechnics, and Transport.' },
];

const SEED_USERS = [
  { name: 'Admin User', email: 'admin@bubt.edu.bd', password: 'admin123', role: 'admin', department: 'CSE' },
  { name: 'Sarah Smith', email: 'sarah@bubt.edu.bd', password: 'contrib123', role: 'contributor', department: 'CSE' },
  { name: 'John Doe', email: 'john@bubt.edu.bd', password: 'student123', role: 'student', department: 'CSE' },
];

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅  Connected to MongoDB');

    // ── Clear existing data ──────────────────────────────────────────────
    console.log('🗑   Clearing existing data...');
    await Promise.all([
      Department.deleteMany({}),
      Course.deleteMany({}),
      User.deleteMany({}),
      Material.deleteMany({}),
    ]);

    // ── Departments ──────────────────────────────────────────────────────
    console.log('📁  Seeding departments...');
    const depts = await Department.insertMany(DEPARTMENTS);
    const deptMap = {};
    depts.forEach((d) => { deptMap[d.code] = d._id; });
    console.log(`   Created ${depts.length} departments`);

    // ── Courses ──────────────────────────────────────────────────────────
    console.log('📚  Seeding courses...');
    const COURSES = [
      { name: 'Structured Programming Language', code: 'CSE 101', departmentId: deptMap['CSE'] },
      { name: 'Object Oriented Programming',      code: 'CSE 201', departmentId: deptMap['CSE'] },
      { name: 'Data Structures & Algorithms',     code: 'CSE 203', departmentId: deptMap['CSE'] },
      { name: 'Database Management Systems',      code: 'CSE 307', departmentId: deptMap['CSE'] },
      { name: 'Electrical Circuits I',            code: 'EEE 101', departmentId: deptMap['EEE'] },
      { name: 'Electronics I',                    code: 'EEE 201', departmentId: deptMap['EEE'] },
      { name: 'Introduction to Business',         code: 'BBA 101', departmentId: deptMap['BBA'] },
      { name: 'Principles of Accounting',         code: 'BBA 203', departmentId: deptMap['BBA'] },
    ];
    const courses = await Course.insertMany(COURSES);
    const courseMap = {};
    courses.forEach((c) => { courseMap[c.code] = c._id; });
    console.log(`   Created ${courses.length} courses`);

    // ── Users ────────────────────────────────────────────────────────────
    console.log('👤  Seeding users...');
    const createdUsers = await User.insertMany(
      await Promise.all(
        SEED_USERS.map(async (u) => ({
          ...u,
          password: await bcrypt.hash(u.password, 12),
        }))
      )
    );
    const contribUser = createdUsers.find((u) => u.role === 'contributor');
    console.log(`   Created ${createdUsers.length} users`);

    // ── Materials ────────────────────────────────────────────────────────
    console.log('📄  Seeding materials...');
    const MATERIALS = [
      {
        title: 'Pointers & Recursion Lecture Notes',
        description: 'Complete slide deck and handwritten code annotations covering pointers and recursive logic.',
        type: 'notes',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        courseId: courseMap['CSE 101'],
        departmentId: deptMap['CSE'],
        uploadedBy: contribUser._id,
        contributorName: contribUser.name,
        status: 'approved',
      },
      {
        title: 'OOP Design Patterns Cheat-Sheet',
        description: 'Overview of Singleton, Factory, and Strategy patterns in Java.',
        type: 'notes',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        courseId: courseMap['CSE 201'],
        departmentId: deptMap['CSE'],
        uploadedBy: contribUser._id,
        contributorName: contribUser.name,
        status: 'approved',
      },
      {
        title: 'Graph Algorithms Assignment (Solved)',
        description: 'Detailed answers explaining Dijkstra, DFS, and BFS shortest-path algorithms.',
        type: 'assignment',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        courseId: courseMap['CSE 203'],
        departmentId: deptMap['CSE'],
        uploadedBy: contribUser._id,
        contributorName: contribUser.name,
        status: 'approved',
      },
      {
        title: 'Database Normalization Explained',
        description: 'Full video walkthrough showing 1NF, 2NF, and 3NF decomposition.',
        type: 'video',
        videoLink: 'https://www.youtube.com/watch?v=KzV_2Z1t3S4',
        courseId: courseMap['CSE 307'],
        departmentId: deptMap['CSE'],
        uploadedBy: contribUser._id,
        contributorName: contribUser.name,
        status: 'approved',
      },
      {
        title: 'Electronics Circuit Theorem Reference Sheet',
        description: 'Handwritten reference sheet covering Thevenin, Norton, and Superposition theorems.',
        type: 'notes',
        fileUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        courseId: courseMap['EEE 101'],
        departmentId: deptMap['EEE'],
        uploadedBy: contribUser._id,
        contributorName: contribUser.name,
        status: 'pending',
      },
      {
        title: 'Crash Course: Financial Statement Analysis',
        description: 'YouTube tutorial covering profit/loss accounts and balance sheet metrics.',
        type: 'video',
        videoLink: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        courseId: courseMap['BBA 203'],
        departmentId: deptMap['BBA'],
        uploadedBy: contribUser._id,
        contributorName: contribUser.name,
        status: 'pending',
      },
    ];

    await Material.insertMany(MATERIALS);
    console.log(`   Created ${MATERIALS.length} materials`);

    // ── Summary ──────────────────────────────────────────────────────────
    console.log('\n✅  Seed complete!\n');
    console.log('🔑  Test credentials:');
    console.log('   Admin:       admin@bubt.edu.bd     / admin123');
    console.log('   Contributor: sarah@bubt.edu.bd     / contrib123');
    console.log('   Student:     john@bubt.edu.bd      / student123');

    await mongoose.connection.close();
    process.exit(0);
  } catch (err) {
    console.error('❌  Seed failed:', err);
    await mongoose.connection.close();
    process.exit(1);
  }
}

seed();
