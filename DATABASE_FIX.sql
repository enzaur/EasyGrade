-- Run this SQL in your Supabase SQL Editor to fix the 404 error
-- This creates the missing tables and columns needed for the gradebook functionality

-- Add missing columns to class table if they don't exist
ALTER TABLE public.class ADD COLUMN IF NOT EXISTS section text;
ALTER TABLE public.class ADD COLUMN IF NOT EXISTS class_code text;
ALTER TABLE public.class ADD COLUMN IF NOT EXISTS is_archived boolean DEFAULT false;

-- Add missing column to student table if it doesn't exist
ALTER TABLE public.student ADD COLUMN IF NOT EXISTS student_code text;

-- Update existing students to have student codes if they don't have them
-- This generates student codes based on student_id
UPDATE public.student 
SET student_code = 'STU-' || LPAD(student_id::text, 5, '0')
WHERE student_code IS NULL OR student_code = '';

-- Create grade_component_items table
CREATE TABLE IF NOT EXISTS public.grade_component_items (
  item_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  class_id bigint NOT NULL,
  component_id bigint NOT NULL,
  title text NOT NULL,
  number_of_items integer NOT NULL DEFAULT 100,
  created_at timestamp with time zone DEFAULT now(),
  term_id bigint,
  CONSTRAINT grade_component_items_pkey PRIMARY KEY (item_id),
  CONSTRAINT grade_component_items_class_fkey FOREIGN KEY (class_id) REFERENCES public.class(class_id) ON DELETE CASCADE,
  CONSTRAINT grade_component_items_component_fkey FOREIGN KEY (component_id) REFERENCES public.grade_component(component_id) ON DELETE CASCADE,
  CONSTRAINT grade_component_items_term_fkey FOREIGN KEY (term_id) REFERENCES public.term(term_id) ON DELETE SET NULL
);

-- Create item_scores table (THIS FIXES THE 404 ERROR)
CREATE TABLE IF NOT EXISTS public.item_scores (
  score_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  student_id bigint NOT NULL,
  item_id bigint NOT NULL,
  score double precision NOT NULL DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT item_scores_pkey PRIMARY KEY (score_id),
  CONSTRAINT item_scores_student_item_unique UNIQUE (student_id, item_id),
  CONSTRAINT item_scores_student_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id) ON DELETE CASCADE,
  CONSTRAINT item_scores_item_fkey FOREIGN KEY (item_id) REFERENCES public.grade_component_items(item_id) ON DELETE CASCADE
);

-- Create attendance table
CREATE TABLE IF NOT EXISTS public.attendance (
  attendance_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  class_id bigint NOT NULL,
  student_id bigint NOT NULL,
  attendance_date date NOT NULL,
  term_id bigint,
  status text NOT NULL DEFAULT 'Present',
  CONSTRAINT attendance_pkey PRIMARY KEY (attendance_id),
  CONSTRAINT attendance_class_fkey FOREIGN KEY (class_id) REFERENCES public.class(class_id) ON DELETE CASCADE,
  CONSTRAINT attendance_student_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id) ON DELETE CASCADE,
  CONSTRAINT attendance_term_fkey FOREIGN KEY (term_id) REFERENCES public.term(term_id) ON DELETE SET NULL
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_item_scores_student ON public.item_scores(student_id);
CREATE INDEX IF NOT EXISTS idx_item_scores_item ON public.item_scores(item_id);
CREATE INDEX IF NOT EXISTS idx_attendance_class_date ON public.attendance(class_id, attendance_date);
CREATE INDEX IF NOT EXISTS idx_attendance_student_term ON public.attendance(student_id, term_id);

-- Enable Row Level Security (RLS) for public access to student grades
ALTER TABLE public.item_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade_component_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- Create policies to allow public read access (for student grade viewing)
CREATE POLICY "Allow public read access to item_scores" ON public.item_scores
  FOR SELECT USING (true);

CREATE POLICY "Allow public read access to grade_component_items" ON public.grade_component_items
  FOR SELECT USING (true);

CREATE POLICY "Allow public read access to attendance" ON public.attendance
  FOR SELECT USING (true);

-- Allow authenticated users to insert/update (for teachers)
CREATE POLICY "Allow authenticated insert to item_scores" ON public.item_scores
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow authenticated update to item_scores" ON public.item_scores
  FOR UPDATE USING (true);

CREATE POLICY "Allow authenticated insert to grade_component_items" ON public.grade_component_items
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow authenticated update to grade_component_items" ON public.grade_component_items
  FOR UPDATE USING (true);

CREATE POLICY "Allow authenticated delete to grade_component_items" ON public.grade_component_items
  FOR DELETE USING (true);

CREATE POLICY "Allow authenticated insert to attendance" ON public.attendance
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow authenticated update to attendance" ON public.attendance
  FOR UPDATE USING (true);
