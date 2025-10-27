# Troubleshooting Guide

## "Class not found" Error

If you're getting a "Class not found" error when opening the student grade link, follow these steps:

### Step 1: Run the Database Fix SQL

1. Open your **Supabase Dashboard**
2. Go to **SQL Editor**
3. Copy and paste the entire contents of `DATABASE_FIX.sql`
4. Click **Run**

This will:
- Add missing columns to the `class` table (`section`, `class_code`, `is_archived`)
- Add missing column to the `student` table (`student_code`)
- Create missing tables (`grade_component_items`, `item_scores`, `attendance`)
- Set up proper security policies

### Step 2: Verify Your Class Data

Make sure your classes have the required data:

```sql
-- Check your classes
SELECT class_id, class_name, section, school_year_id 
FROM public.class;
```

If `section` is NULL, update it:

```sql
-- Add sections to existing classes
UPDATE public.class 
SET section = 'A' 
WHERE section IS NULL;
```

### Step 3: Check the Class ID in the URL

The URL should look like:
```
http://localhost:5173/#/student-grade?class=1
```

Make sure the `class=X` number matches an actual `class_id` in your database.

### Step 4: Verify Students Have Student Codes

```sql
-- Check students
SELECT student_id, student_name, student_code, class_id 
FROM public.student;
```

If `student_code` is NULL, the fix SQL will auto-generate them as `STU-00001`, `STU-00002`, etc.

## Common Issues

### 1. 404 Error on item_scores
**Solution**: Run `DATABASE_FIX.sql` - this creates the missing `item_scores` table.

### 2. "Column does not exist" errors
**Solution**: Run `DATABASE_FIX.sql` - this adds missing columns to existing tables.

### 3. QR Code not generating
**Issue**: The QR code uses an external API. Check your internet connection.
**Alternative**: Just use the link directly and share it with students.

### 4. Student can't see their grades
**Check**:
- Student is entering the correct Student ID (check the `student_code` column)
- Student belongs to the class (check `class_id` matches)
- Grades have been entered in the gradebook

## Testing the Flow

### As Teacher:
1. Go to Gradebook
2. Select a School Year and Class
3. Click "Share Class Link"
4. Copy the link or download the QR code

### As Student:
1. Open the link or scan QR code
2. See the class name
3. Enter your Student ID (e.g., `STU-00001`)
4. Click "View My Grades"
5. See your personalized grades

## Need More Help?

Check the browser console (F12) for detailed error messages. The error messages will tell you exactly what's missing.
