# Supabase Setup Instructions

## 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Sign up or log in to your account
3. Click "New Project"
4. Choose your organization and enter project details
5. Wait for the project to be created

## 2. Set up the Database

1. Go to the SQL Editor in your Supabase dashboard
2. Run the following SQL commands to create your tables:

```sql
-- Create schoolyear table
CREATE TABLE public.schoolyear (
  school_year_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  school_year text NOT NULL,
  CONSTRAINT schoolyear_pkey PRIMARY KEY (school_year_id)
);

-- Create instructor table
CREATE TABLE public.instructor (
  instructor_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  instructor_name text NOT NULL,
  password character varying,
  instructor_user_id character varying NOT NULL,
  CONSTRAINT instructor_pkey PRIMARY KEY (instructor_id)
);

-- Create class table
CREATE TABLE public.class (
  class_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  class_name text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  school_year_id bigint NOT NULL,
  instructor_id bigint NOT NULL,
  CONSTRAINT class_pkey PRIMARY KEY (class_id),
  CONSTRAINT class_school_year_fkey FOREIGN KEY (school_year_id) REFERENCES public.schoolyear(school_year_id),
  CONSTRAINT class_instructor_fkey FOREIGN KEY (instructor_id) REFERENCES public.instructor(instructor_id)
);

-- Create student table
CREATE TABLE public.student (
  student_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  student_name text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  class_id bigint NOT NULL,
  CONSTRAINT student_pkey PRIMARY KEY (student_id),
  CONSTRAINT student_class_fkey FOREIGN KEY (class_id) REFERENCES public.class(class_id)
);

-- Create term table
CREATE TABLE public.term (
  term_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  term_name character varying NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT term_pkey PRIMARY KEY (term_id)
);

-- Create grade_component table
CREATE TABLE public.grade_component (
  component_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  component_name character varying NOT NULL,
  number_of_items integer NOT NULL DEFAULT 1,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT grade_component_pkey PRIMARY KEY (component_id)
);

-- Create grade_percentage table
CREATE TABLE public.grade_percentage (
  percentage_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  percentage double precision NOT NULL,
  component_id bigint NOT NULL,
  CONSTRAINT grade_percentage_pkey PRIMARY KEY (percentage_id),
  CONSTRAINT grade_percentage_component_fkey FOREIGN KEY (component_id) REFERENCES public.grade_component(component_id)
);

-- Create grade table
CREATE TABLE public.grade (
  grade_id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  updated_at timestamp without time zone NOT NULL DEFAULT now(),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  grade_value double precision NOT NULL,
  student_id bigint NOT NULL,
  term_id bigint NOT NULL,
  component_id bigint NOT NULL,
  school_year_id bigint NOT NULL,
  CONSTRAINT grade_pkey PRIMARY KEY (grade_id),
  CONSTRAINT grade_student_fkey FOREIGN KEY (student_id) REFERENCES public.student(student_id),
  CONSTRAINT grade_term_fkey FOREIGN KEY (term_id) REFERENCES public.term(term_id),
  CONSTRAINT grade_component_fkey FOREIGN KEY (component_id) REFERENCES public.grade_component(component_id),
  CONSTRAINT grade_school_year_fkey FOREIGN KEY (school_year_id) REFERENCES public.schoolyear(school_year_id)
);

-- Create grade_component_items table
CREATE TABLE public.grade_component_items (
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

-- Create item_scores table
CREATE TABLE public.item_scores (
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
CREATE TABLE public.attendance (
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
CREATE INDEX idx_item_scores_student ON public.item_scores(student_id);
CREATE INDEX idx_item_scores_item ON public.item_scores(item_id);
CREATE INDEX idx_attendance_class_date ON public.attendance(class_id, attendance_date);
CREATE INDEX idx_attendance_student_term ON public.attendance(student_id, term_id);
```

## 3. Configure Environment Variables

1. Copy the `env.example` file to `.env` in your project root
2. Get your Supabase URL and anon key from your project settings
3. Update the `.env` file with your actual values:

```
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
```

## 4. Insert Sample Data (Optional)

You can insert some sample data to test the application:

```sql
-- Insert sample school year
INSERT INTO public.schoolyear (school_year) VALUES ('2024-2025');

-- Insert sample instructor
INSERT INTO public.instructor (instructor_name, instructor_user_id, password) 
VALUES ('John Doe', 'john.doe', 'password123');

-- Insert sample term
INSERT INTO public.term (term_name) VALUES ('First Semester');

-- Insert sample grade components
INSERT INTO public.grade_component (component_name, number_of_items) 
VALUES ('Quizzes', 10), ('Exams', 3), ('Projects', 2), ('Participation', 1);
```

## 5. Run the Application

1. Install dependencies: `npm install`
2. Start the development server: `npm run dev`
3. Open your browser and navigate to the application

## Notes

- Make sure to replace the sample instructor credentials with your own
- The application uses localStorage for session management
- All database operations are handled through the DatabaseService class
- The application includes proper TypeScript types for all database tables
