import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY')
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Database types based on your SQL schema
export interface SchoolYear {
  school_year_id: number
  school_year: string
}

export interface Instructor {
  instructor_id: number
  instructor_name: string
  password?: string
  instructor_user_id: string
  email?: string
}

export interface Class {
  class_id: number
  class_name: string
  created_at: string
  // Schema in prompt lacks explicit columns, but app may add these
  // Keep optional to avoid type errors if absent in DB
  school_year_id?: number
  instructor_id?: number
}

export interface Student {
  student_id: number
  student_name: string
  created_at: string
  class_id?: number
}

export interface Term {
  term_id: number
  term_name: string
  created_at: string
}

export interface GradeComponent {
  component_id: number
  component_name: string
  number_of_items: number
  created_at: string
}

export interface GradePercentage {
  percentage_id: number
  percentage: number
  component_id?: number
}

export interface Grade {
  grade_id: number
  updated_at: string
  created_at: string
  grade_value: number
  student_id?: number
  term_id?: number
  component_id?: number
  school_year_id?: number
}

// Extended types for joins
export interface StudentWithClass extends Student {
  class: Class
}

export interface GradeWithDetails extends Grade {
  student: Student
  term: Term
  grade_component: GradeComponent
  school_year: SchoolYear
}

export interface ClassWithDetails extends Class {
  school_year: SchoolYear
  instructor: Instructor
  students: Student[]
}
